# frozen_string_literal: true

require File.expand_path("../test_helper", __dir__)

module TypeSafe
  class ErrorsTest < Test::Unit::TestCase
    context "APIError.from_response" do
      should "pick the error class from the status" do
        {
          400 => BadRequestError, 401 => AuthenticationError, 403 => PermissionDeniedError,
          404 => NotFoundError, 422 => UnprocessableEntityError, 429 => RateLimitError,
          500 => InternalServerError, 503 => InternalServerError, 529 => OverloadedError, 418 => APIError
        }.each do |status, klass|
          e = APIError.from_response(build_response(status, ""))
          assert_instance_of klass, e, "status #{status}"
          assert_kind_of Error, e
        end
        assert_kind_of InternalServerError, APIError.from_response(build_response(529, ""))
      end

      should "expose status, body, headers, endpoint and request id" do
        e = APIError.from_response(
          build_response(401, '{"error":{"message":"Invalid API key"}}', { "X-TypeSafe-Request-Id" => "req_1" })
        )
        assert_equal 401, e.status
        assert_equal({ "error" => { "message" => "Invalid API key" } }, e.body)
        assert_equal "req_1", e.request_id
        assert_equal "POST https://api.typesafe.ai/v1/systemone", e.endpoint
        assert_equal "[401] POST https://api.typesafe.ai/v1/systemone: Invalid API key (request_id: req_1)", e.message
      end

      should "keep a text body or nil when the body is not JSON" do
        assert_equal "Bad gateway", APIError.from_response(build_response(502, "Bad gateway")).body
        assert_nil APIError.from_response(build_response(502, "")).body
      end
    end

    context "RateLimitError" do
      should "expose retry_after from the headers" do
        assert_in_delta 2.0, APIError.from_response(build_response(429, "", { "retry-after" => "2" })).retry_after
        assert_nil APIError.from_response(build_response(429, "")).retry_after
      end
    end

    context "APITimeoutError" do
      should "be a connection error carrying the timeout" do
        e = APITimeoutError.new(timeout: 3)
        assert_kind_of APIConnectionError, e
        assert_equal 3, e.timeout
        assert_match(/3s/, e.message)
      end
    end

    context "APIResponseValidationError" do
      should "carry the field path" do
        e = APIResponseValidationError.new(field_path: "answers.tone.confidence", status: 200)
        assert_equal "answers.tone.confidence", e.field_path
        assert_kind_of APIError, e
        assert_match(/answers\.tone\.confidence/, e.message)
      end
    end
  end
end
