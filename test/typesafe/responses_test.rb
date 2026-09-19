# frozen_string_literal: true

require File.expand_path("../test_helper", __dir__)

module TypeSafe
  class SystemOneResponseTest < Test::Unit::TestCase
    def http(body, headers: {})
      body = JSON.generate(body) unless body.is_a?(String)
      build_response(200, body, { "x-typesafe-request-id" => "req_9" }.merge(headers))
    end

    context ".from_http" do
      should "parse the example response from the API reference" do
        response = Responses::SystemOneResponse.from_http(http(system_one_response_fixture))
        assert_equal "jev-1.13.0", response.model
        assert_equal 312, response.usage.input_tokens
        assert_equal 48, response.usage.output_tokens
        assert_equal "req_9", response.request_id
        assert_equal %w[department frustration is_urgent], response.answers.keys
        assert_equal fixture_json("system_one_response.json"), response.to_h
        assert_true response.frozen?
      end

      should "expose choice answers" do
        choice = Responses::SystemOneResponse.from_http(http(system_one_response_fixture)).choices[:department]
        assert_instance_of Responses::ChoiceAnswer, choice
        assert_equal "billing", choice.choice
        assert_in_delta 0.84, choice.probabilities[:billing]
        assert_in_delta 0.596, choice.confidence
      end

      should "expose score answers with integer level keys" do
        score = Responses::SystemOneResponse.from_http(http(system_one_response_fixture)).scores["frustration"]
        assert_in_delta 1.035, score.score
        assert_equal({ 0 => "Calm, just stating facts", 1 => "Frustrated but civil", 2 => "Very angry, strong language" },
                     score.legend)
        assert_in_delta 0.765, score.probabilities[1]
        assert_equal "Frustrated but civil", score.raw_legend["1"]
        assert_in_delta 0.842, score.confidence
      end

      should "expose noul answers and indifferent lookup" do
        response = Responses::SystemOneResponse.from_http(http(system_one_response_fixture))
        assert_in_delta 0.999, response.nouls[:is_urgent].noul
        assert_same response[:is_urgent], response.answers["is_urgent"]
      end

      should "group answers by type" do
        response = Responses::SystemOneResponse.from_http(http(system_one_response_fixture))
        assert_equal ["is_urgent"], response.nouls.keys
        assert_equal ["department"], response.choices.keys
        assert_equal ["frustration"], response.scores.keys
      end

      should "keep unknown answer types and extra fields" do
        body = { "model" => "m", "usage" => {},
                 "answers" => { "q" => { "type" => "rank", "order" => %w[a b] },
                                "n" => { "type" => "noul", "noul" => 0.5, "extra" => 1 } } }
        response = Responses::SystemOneResponse.from_http(http(body))
        assert_instance_of Responses::UnknownAnswer, response[:q]
        assert_equal %w[a b], response[:q].raw["order"]
        assert_equal 1, response[:n].to_h["extra"]
        assert_nil response.usage.input_tokens
      end

      should "raise a validation error with the field path" do
        cases = {
          "model" => { "usage" => {}, "answers" => {} },
          "usage" => { "model" => "m", "answers" => {} },
          "answers.q.type" => { "model" => "m", "usage" => {}, "answers" => { "q" => { "noul" => 1 } } },
          "answers.q.noul" => { "model" => "m", "usage" => {}, "answers" => { "q" => { "type" => "noul", "noul" => "x" } } },
          "answers.q.confidence" => { "model" => "m", "usage" => {},
                                      "answers" => { "q" => { "type" => "choice", "choice" => "a",
                                                              "probabilities" => { "a" => 1 } } } },
          "answers.q.legend.x" => { "model" => "m", "usage" => {},
                                    "answers" => { "q" => { "type" => "score", "score" => 1, "legend" => { "x" => "a" },
                                                            "probabilities" => { "0" => 1 }, "confidence" => 1 } } }
        }
        cases.each do |path, body|
          e = assert_raise(APIResponseValidationError, path) { Responses::SystemOneResponse.from_http(http(body)) }
          assert_equal path, e.field_path
          assert_equal 200, e.status
        end
      end

      should "raise when the body is not JSON" do
        e = assert_raise(APIResponseValidationError) { Responses::SystemOneResponse.from_http(http("<html>")) }
        assert_equal "$", e.field_path
        assert_equal "<html>", e.body
      end
    end
  end

  class ListModelsResponseTest < Test::Unit::TestCase
    should "parse model cards" do
      response = Responses::ListModelsResponse.from_http(build_response(200, list_models_response_fixture,
                                                                        { "x-typesafe-request-id" => "req_9" }))
      assert_equal %w[jev-latest jev-preview], response.names
      assert_equal "2026-08-01", response.first.release_date
      assert_equal 2, response.count
      assert_equal "req_9", response.request_id
    end

    should "raise a validation error for malformed entries" do
      e = assert_raise(APIResponseValidationError) do
        Responses::ListModelsResponse.from_http(build_response(200, '{"models":[{"description":"x"}]}'))
      end
      assert_equal "models[0].name", e.field_path
    end
  end
end
