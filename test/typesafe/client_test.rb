# frozen_string_literal: true

require File.expand_path("../test_helper", __dir__)

module TypeSafe
  class ClientTest < Test::Unit::TestCase
    QUESTIONS = {
      department: Choice.new(instructions: "Which team should handle this",
                             criteria: { billing: "Payment", technical: "Bugs", sales: "Pricing" }),
      frustration: Score.new(instructions: "How frustrated the customer appears",
                             criteria: ["Calm, just stating facts", "Frustrated but civil",
                                        "Very angry, strong language"]),
      is_urgent: Noul.new(instructions: "The message conveys urgency or time-sensitivity")
    }.freeze

    context "#system_one" do
      should "send the request and parse the answers" do
        stub_request(:post, SYSTEM_ONE_URL)
          .with(headers: { "Authorization" => "Bearer #{API_KEY}", "Content-Type" => "application/json" })
          .to_return(json_response(system_one_response_fixture, headers: { "x-typesafe-request-id" => "r1" }))

        response = build_client.system_one(state: "Help! Payouts failing.", questions: QUESTIONS)

        assert_requested(:post, SYSTEM_ONE_URL, body: {
                           "state" => "Help! Payouts failing.",
                           "model" => "jev-latest",
                           "questions" => QUESTIONS.transform_keys(&:to_s).transform_values(&:to_h)
                         })
        assert_equal "billing", response.choices[:department].choice
        assert_in_delta 1.035, response.scores[:frustration].score
        assert_in_delta 0.999, response.nouls[:is_urgent].noul
        assert_equal "r1", response.request_id
        assert_equal 200, response.http_response.status
      end

      should "accept a model override, structured state and extra_body" do
        stub_request(:post, SYSTEM_ONE_URL).to_return(json_response(system_one_response_fixture))
        build_client(model: "jev-1.13.0").system_one(
          state: { message: "hi", tags: [:vip] }, questions: { q: { type: "noul", instructions: "Urgent?" } },
          model: "jev-preview", request_options: { extra_body: { trace: true, model: "override" } }
        )
        assert_requested(:post, SYSTEM_ONE_URL, body: {
                           "state" => { "message" => "hi", "tags" => ["vip"] },
                           "model" => "override",
                           "questions" => { "q" => { "type" => "noul", "instructions" => "Urgent?" } },
                           "trace" => true
                         })
      end

      should "use the client default model" do
        stub_request(:post, SYSTEM_ONE_URL).to_return(json_response(system_one_response_fixture))
        build_client(model: "jev-1.13.0").system_one(state: "x", questions: { q: Noul.new })
        assert_requested(:post, SYSTEM_ONE_URL, body: hash_including("model" => "jev-1.13.0"))
      end

      should "validate before sending anything" do
        client = build_client
        assert_raise(ValidationError) { client.system_one(state: "x", questions: {}) }
        assert_raise(ValidationError) { client.system_one(state: nil, questions: { q: Noul.new }) }
        assert_raise(ValidationError) { client.system_one(state: "x", questions: { q: Noul.new }, model: " ") }
        assert_raise(ArgumentError) { client.system_one(state: "x", questions: { q: Noul.new }, request_options: { bogus: 1 }) }
        assert_not_requested :post, SYSTEM_ONE_URL
      end

      should "raise API errors" do
        stub_request(:post, SYSTEM_ONE_URL).to_return(status: 422, body: '{"detail":[{"loc":["body","questions"]}]}')
        e = assert_raise(UnprocessableEntityError) { build_client.system_one(state: "x", questions: { q: Noul.new }) }
        assert_equal 422, e.status
        assert_equal [{ "loc" => %w[body questions] }], e.body["detail"]
      end

      should "use a custom transport" do
        transport = FakeTransport.new({ status: 200, headers: {}, body: system_one_response_fixture })
        response = build_client(transport: transport).system_one(state: "x", questions: { q: Noul.new })
        assert_equal "jev-1.13.0", response.model
        assert_equal 1, transport.requests.size
        assert_not_requested :post, SYSTEM_ONE_URL
      end
    end

    context "#models" do
      should "list the models" do
        stub_request(:get, MODELS_URL)
          .with(headers: { "Authorization" => "Bearer #{API_KEY}" })
          .to_return(json_response(list_models_response_fixture))
        assert_equal %w[jev-latest jev-preview], build_client.models.list.names
      end
    end

    should "require an API key" do
      assert_raise(ConfigurationError) { Client.new(api_key: nil) }
    end
  end

  class GlobalConfigTest < Test::Unit::TestCase
    context ".configure" do
      should "build and memoize the default client" do
        TypeSafe.configure { |c| c.model = "jev-1.13.0" }
        client = TypeSafe.client
        assert_equal API_KEY, client.config.api_key
        assert_equal "jev-1.13.0", client.config.model
        assert_same client, TypeSafe.client
      end

      should "rebuild the default client after reconfiguring" do
        client = TypeSafe.client
        TypeSafe.configure { |c| c.model = "jev-preview" }
        assert_not_same client, TypeSafe.client
        assert_equal "jev-preview", TypeSafe.client.config.model
      end
    end

    context ".client" do
      should "read the API key from the environment" do
        TypeSafe.reset!
        ENV["TYPESAFE_API_KEY"] = "env-key"
        assert_equal "env-key", TypeSafe.client.config.api_key
      ensure
        ENV.delete("TYPESAFE_API_KEY")
      end
    end
  end
end
