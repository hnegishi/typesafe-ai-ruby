# frozen_string_literal: true

require File.expand_path("../test_helper", __dir__)

module TypeSafe
  class ConstantsTest < Test::Unit::TestCase
    should "use the same environment variable names as the official SDKs" do
      assert_equal "TYPESAFE_API_KEY", Constants::API_KEY_ENV
      assert_equal "TYPESAFE_BASE_URL", Constants::BASE_URL_ENV
      assert_equal "TYPESAFE_DEFAULT_MODEL", Constants::DEFAULT_MODEL_ENV
      assert_equal "TYPESAFE_LOG_LEVEL", Constants::LOG_LEVEL_ENV
    end

    should "use the same defaults as the official SDKs" do
      assert_equal "https://api.typesafe.ai", Constants::DEFAULT_BASE_URL
      assert_equal "jev-latest", Constants::DEFAULT_MODEL
      assert_in_delta 10.0, Constants::DEFAULT_TIMEOUT
      assert_equal :warn, Constants::DEFAULT_LOG_LEVEL
    end

    should "know the endpoint paths and header names" do
      assert_equal "/v1/systemone", Constants::SYSTEM_ONE_PATH
      assert_equal "/v1/models", Constants::MODELS_PATH
      assert_equal "X-TypeSafe-SDK", Constants::Headers::SDK
      assert_equal "X-TypeSafe-Runtime", Constants::Headers::RUNTIME
      assert_equal "X-TypeSafe-Retry-Count", Constants::Headers::RETRY_COUNT
      assert_equal "x-typesafe-request-id", Constants::Headers::REQUEST_ID
    end
  end
end
