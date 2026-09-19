# frozen_string_literal: true

require File.expand_path("../test_helper", __dir__)

module TypeSafe
  class InstrumentationTest < Test::Unit::TestCase
    setup do
      @sleeps = []
      @begins = []
      @ends = []
      Instrumentation.subscribe(:request_begin) { |event| @begins << event }
      Instrumentation.subscribe(:request_end) { |event| @ends << event }
    end

    def build_requestor(transport, **options)
      config = Configuration.new(api_key: "k", logger: Logger.new(File::NULL), **options).resolve(env: {})
      HTTP::Requestor.new(config, transport: transport, sleeper: ->(s) { @sleeps << s })
    end

    context ".subscribe" do
      should "reject unknown topics and missing blocks" do
        assert_raise(ArgumentError) { Instrumentation.subscribe(:request_start) { nil } }
        assert_raise(ArgumentError) { Instrumentation.subscribe(:request_end) }
      end

      should "replace a subscriber with the same name and support unsubscribe" do
        calls = []
        Instrumentation.subscribe(:request_end, :mine) { calls << :first }
        Instrumentation.subscribe(:request_end, :mine) { calls << :second }
        Instrumentation.notify(:request_end, :event)
        assert_equal [:second], calls

        Instrumentation.unsubscribe(:request_end, :mine)
        Instrumentation.notify(:request_end, :event)
        assert_equal [:second], calls
      end
    end

    context "request events" do
      should "fire once per successful call" do
        transport = FakeTransport.new({ status: 200, headers: { "x-typesafe-request-id" => "req_1" }, body: "{}" })
        build_requestor(transport).get("/v1/models")

        assert_equal 1, @begins.size
        assert_equal :get, @begins.first.method
        assert_equal "/v1/models", @begins.first.path

        event = @ends.first
        assert_equal 1, @ends.size
        assert_equal :get, event.method
        assert_equal "/v1/models", event.path
        assert_equal 200, event.http_status
        assert_equal 0, event.num_retries
        assert_equal "req_1", event.request_id
        assert_nil event.error
        assert_kind_of Float, event.duration
        assert_true event.frozen?
      end

      should "report retries and the final error" do
        transport = FakeTransport.new(APIConnectionError.new("reset"),
                                      { status: 503, headers: { "x-typesafe-request-id" => "req_9" }, body: "" },
                                      { status: 503, headers: {}, body: "" })
        assert_raise(InternalServerError) { build_requestor(transport).post("/v1/systemone", body: {}) }

        event = @ends.first
        assert_equal 1, @ends.size
        assert_equal :post, event.method
        assert_equal 503, event.http_status
        assert_equal 2, event.num_retries
        assert_kind_of InternalServerError, event.error
      end

      should "report connection errors without a status" do
        transport = FakeTransport.new(APITimeoutError.new(timeout: 1))
        assert_raise(APITimeoutError) do
          build_requestor(transport, retry_policy: { max_retries: 0 }).get("/v1/models")
        end
        assert_nil @ends.first.http_status
        assert_kind_of APITimeoutError, @ends.first.error
      end

      should "carry user_data from begin to end" do
        Instrumentation.subscribe(:request_begin) { |event| event.user_data[:started_by] = "test" }
        build_requestor(FakeTransport.new({ status: 200, headers: {}, body: "{}" })).get("/v1/models")
        assert_equal({ started_by: "test" }, @ends.first.user_data)
      end
    end
  end
end
