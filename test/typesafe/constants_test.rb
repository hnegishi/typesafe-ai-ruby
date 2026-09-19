# frozen_string_literal: true

require "test_helper"

class ConstantsTest < Minitest::Test
  C = TypeSafe::Constants

  def test_environment_variable_names_match_official_sdks
    assert_equal "TYPESAFE_API_KEY", C::API_KEY_ENV
    assert_equal "TYPESAFE_BASE_URL", C::BASE_URL_ENV
    assert_equal "TYPESAFE_DEFAULT_MODEL", C::DEFAULT_MODEL_ENV
    assert_equal "TYPESAFE_LOG_LEVEL", C::LOG_LEVEL_ENV
  end

  def test_defaults_match_official_sdks
    assert_equal "https://api.typesafe.ai", C::DEFAULT_BASE_URL
    assert_equal "jev-latest", C::DEFAULT_MODEL
    assert_in_delta 10.0, C::DEFAULT_TIMEOUT
    assert_equal :warn, C::DEFAULT_LOG_LEVEL
  end

  def test_endpoint_paths
    assert_equal "/v1/systemone", C::SYSTEM_ONE_PATH
    assert_equal "/v1/models", C::MODELS_PATH
  end

  def test_header_names
    assert_equal "X-TypeSafe-SDK", C::Headers::SDK
    assert_equal "X-TypeSafe-Runtime", C::Headers::RUNTIME
    assert_equal "X-TypeSafe-Retry-Count", C::Headers::RETRY_COUNT
    assert_equal "x-typesafe-request-id", C::Headers::REQUEST_ID
  end
end
