# frozen_string_literal: true

require File.expand_path("../test_helper", __dir__)

module TypeSafe
  # Exercises the real API. Skipped unless TYPESAFE_API_KEY is set:
  #
  #   TYPESAFE_API_KEY=... bundle exec rake test:integration
  #
  # Assertions check the shape of the answers rather than exact values, since the model's
  # output can change between releases.
  class LiveAPITest < Test::Unit::TestCase
    TICKET = "Hi, I've been trying to connect my Stripe account for 3 days and it keeps failing. " \
             "I'm losing sales. Please help ASAP."

    setup do
      omit("set TYPESAFE_API_KEY to run the live API tests") if Util.blank?(ENV.fetch("TYPESAFE_API_KEY", nil))
      WebMock.allow_net_connect!
      @client = Client.new(logger: Logger.new(File::NULL))
    end

    teardown do
      @client&.close
      WebMock.disable_net_connect!
    end

    should "answer the quick start questions" do
      response = @client.system_one(
        state: TICKET,
        questions: {
          department: Choice.new(
            instructions: "Which team should handle this",
            criteria: { billing: "Payment or subscription issues", technical: "Bugs or integration problems",
                        sales: "Pricing or account questions" }
          ),
          frustration: Score.new(
            instructions: "How frustrated the customer appears",
            criteria: ["Calm, just stating facts", "Frustrated but civil", "Very angry, strong language"]
          ),
          is_urgent: Noul.new(instructions: "The message conveys urgency or time-sensitivity")
        }
      )

      assert_match(/\Ajev-/, response.model)
      assert_equal %w[department frustration is_urgent], response.answers.keys.sort
      assert_operator response.usage.input_tokens, :>, 0

      department = response.choices[:department]
      assert_includes %w[billing technical sales], department.choice
      assert_equal %w[billing sales technical], department.probabilities.keys.sort
      assert_in_delta 1.0, department.probabilities.values.sum, 0.01
      assert_includes 0.0..1.0, department.confidence
      assert_equal department.choice, department.probabilities.max_by { |_, p| p }.first

      frustration = response.scores[:frustration]
      assert_includes 0.0..2.0, frustration.score
      assert_equal [0, 1, 2], frustration.legend.keys.sort
      assert_equal "Frustrated but civil", frustration.legend[1]
      assert_in_delta 1.0, frustration.probabilities.values.sum, 0.01
      assert_includes 0.0..1.0, frustration.confidence

      urgency = response.nouls[:is_urgent].noul
      assert_includes 0.0..1.0, urgency
      assert_operator urgency, :>, 0.5, "the ticket says ASAP; expected urgency above 0.5"
    end

    should "accept structured state and raw hash questions" do
      response = @client.system_one(
        state: { subject: "Double charge", body: "I was charged twice this month.", tags: %w[billing] },
        questions: { billing: { type: "noul", instructions: "Is this ticket about billing?" } }
      )
      assert_operator response.nouls[:billing].noul, :>, 0.5
    end

    should "list the models the account can use" do
      models = @client.models.list
      assert_operator models.count, :>=, 1
      assert_includes models.names, "jev-latest"
      models.each do |model|
        assert_kind_of String, model.name
        assert_kind_of String, model.description
        assert_kind_of String, model.release_date
      end
    end

    should "raise AuthenticationError for an invalid key" do
      client = Client.new(api_key: "sk-invalid", logger: Logger.new(File::NULL), retry_policy: { max_retries: 0 })
      e = assert_raise(AuthenticationError) { client.models.list }
      assert_equal 401, e.status
      assert_equal "GET https://api.typesafe.ai/v1/models", e.endpoint
    ensure
      client&.close
    end

    should "raise UnprocessableEntityError for a body the server rejects" do
      e = assert_raise(UnprocessableEntityError) do
        @client.system_one(
          state: "x", questions: { q: Noul.new },
          request_options: { extra_body: { questions: { q: { type: "score", criteria: [] } } }, retry_policy: { max_retries: 0 } }
        )
      end
      assert_equal 422, e.status
      assert_kind_of Array, e.body["detail"], "the server reports validation errors under detail"
      assert_equal %w[body questions q score criteria], e.body["detail"].first["loc"]
      assert_match(%r{\A\[422\] POST https://api\.typesafe\.ai/v1/systemone: .+ \(request_id: req_}, e.message)
    end
  end
end
