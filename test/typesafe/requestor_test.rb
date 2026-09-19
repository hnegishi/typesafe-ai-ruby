# frozen_string_literal: true

require File.expand_path("../test_helper", __dir__)

module TypeSafe
  class RequestorTest < Test::Unit::TestCase
    OK = { status: 200, headers: {}, body: "{}" }.freeze

    def build_requestor(transport, **options)
      config = Configuration.new(api_key: "k", logger: Logger.new(File::NULL), **options).resolve(env: {})
      HTTP::Requestor.new(config, transport: transport)
    end

    context "#post" do
      should "send the SDK headers, the client headers and the per-call headers" do
        transport = FakeTransport.new(OK)
        build_requestor(transport, headers: { "X-Team" => "growth", "authorization" => "hijack" })
          .post("/v1/systemone", body: { "state" => "s" },
                                 options: RequestOptions.new(headers: { "X-Call" => "1", "Accept" => "text/x" }))
        request = transport.requests.first
        assert_equal :post, request.method
        assert_equal "https://api.typesafe.ai/v1/systemone", request.uri.to_s
        assert_equal '{"state":"s"}', request.body
        assert_in_delta 10.0, request.timeout

        headers = request.headers
        assert_equal "Bearer k", headers["Authorization"]
        assert_equal "application/json", headers["Accept"]
        assert_equal "application/json", headers["Content-Type"]
        assert_equal "typesafe-ruby/#{VERSION}", headers["User-Agent"]
        assert_equal "typesafe-ruby/#{VERSION}", headers["X-TypeSafe-SDK"]
        assert_match(%r{\Aruby/\d}, headers["X-TypeSafe-Runtime"])
        assert_equal "growth", headers["X-Team"]
        assert_equal "1", headers["X-Call"]
        assert_false headers.key?("authorization")
        assert_false headers.key?("X-TypeSafe-Retry-Count")
      end
    end

    context "#get" do
      should "send no body and honor a per-call timeout" do
        transport = FakeTransport.new(OK)
        build_requestor(transport, base_url: "http://localhost:9999")
          .get("/v1/models", options: RequestOptions.new(timeout: 3))
        request = transport.requests.first
        assert_equal :get, request.method
        assert_nil request.body
        assert_false request.headers.key?("Content-Type")
        assert_equal 3, request.timeout
        assert_equal "GET http://localhost:9999/v1/models", request.endpoint
      end
    end

    should "raise a typed error for non-2xx responses" do
      transport = FakeTransport.new({ status: 429, headers: { "retry-after-ms" => "250" }, body: '{"error":"slow down"}' })
      e = assert_raise(RateLimitError) { build_requestor(transport).get("/v1/models") }
      assert_in_delta 0.25, e.retry_after
      assert_equal "GET https://api.typesafe.ai/v1/models", e.endpoint
    end

    should "let transport errors propagate" do
      transport = FakeTransport.new(APITimeoutError.new(timeout: 1))
      assert_raise(APITimeoutError) { build_requestor(transport).get("/v1/models") }
    end

    context "logging" do
      should "log a request summary at info" do
        io = StringIO.new
        transport = FakeTransport.new({ status: 200, headers: { "x-typesafe-request-id" => "req_1" }, body: "{}" })
        build_requestor(transport, logger: Logger.new(io), log_level: :info).get("/v1/models")
        assert_match(%r{GET https://api.typesafe.ai/v1/models -> 200 \(\d+ms\) request_id=req_1}, io.string)
      end

      should "stay quiet at warn" do
        io = StringIO.new
        build_requestor(FakeTransport.new(OK), logger: Logger.new(io), log_level: :warn).get("/v1/models")
        assert_empty io.string
      end
    end
  end
end
