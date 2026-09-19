# frozen_string_literal: true

require File.expand_path("../test_helper", __dir__)

module TypeSafe
  class ConfigurationTest < Test::Unit::TestCase
    def resolve(env: {}, **options)
      Configuration.new(**options).resolve(env: env)
    end

    context "#resolve" do
      should "apply SDK defaults" do
        config = resolve(api_key: "k")
        assert_equal "k", config.api_key
        assert_equal "https://api.typesafe.ai", config.base_url
        assert_equal "jev-latest", config.model
        assert_in_delta 10.0, config.timeout
        assert_equal({}, config.headers)
        assert_equal :warn, config.log_level
        assert_kind_of Logger, config.logger
        assert_equal Logger::WARN, config.logger.level
        assert_true config.frozen?
      end

      should "fall back to environment variables" do
        env = {
          "TYPESAFE_API_KEY" => " env-key ", "TYPESAFE_BASE_URL" => "https://example.test/",
          "TYPESAFE_DEFAULT_MODEL" => "jev-1.13.0", "TYPESAFE_LOG_LEVEL" => "debug"
        }
        config = resolve(env: env)
        assert_equal "env-key", config.api_key
        assert_equal "https://example.test", config.base_url
        assert_equal "jev-1.13.0", config.model
        assert_equal :debug, config.log_level
      end

      should "prefer explicit options over environment variables" do
        env = { "TYPESAFE_API_KEY" => "env-key", "TYPESAFE_DEFAULT_MODEL" => "env-model" }
        config = resolve(env: env, api_key: "k", base_url: "http://localhost:8080///", model: "m", log_level: "info")
        assert_equal "k", config.api_key
        assert_equal "http://localhost:8080", config.base_url
        assert_equal "m", config.model
        assert_equal :info, config.log_level
      end

      should "ignore blank environment values" do
        env = { "TYPESAFE_API_KEY" => "k", "TYPESAFE_BASE_URL" => "   ", "TYPESAFE_DEFAULT_MODEL" => "" }
        config = resolve(env: env)
        assert_equal "https://api.typesafe.ai", config.base_url
        assert_equal "jev-latest", config.model
      end

      should "raise when the API key is missing" do
        e = assert_raise(ConfigurationError) { resolve }
        assert_match(/TYPESAFE_API_KEY/, e.message)
        assert_raise(ConfigurationError) { resolve(api_key: "   ") }
      end

      should "raise on invalid values" do
        assert_raise(ConfigurationError) { resolve(api_key: "k", base_url: "not a url") }
        assert_raise(ConfigurationError) { resolve(api_key: "k", base_url: "ftp://x") }
        assert_raise(ConfigurationError) { resolve(api_key: "k", timeout: 0) }
        assert_raise(ConfigurationError) { resolve(api_key: "k", timeout: "10") }
        assert_raise(ConfigurationError) { resolve(api_key: "k", log_level: :loud) }
      end

      should "stringify headers and keep a user supplied logger" do
        logger = Logger.new(File::NULL)
        config = resolve(api_key: "k", headers: { "X-Team": :growth }, logger: logger)
        assert_equal({ "X-Team" => "growth" }, config.headers)
        assert_same logger, config.logger
      end
    end

    context "#to_h" do
      should "only include options that were set" do
        assert_equal({ api_key: "k", timeout: 5 }, Configuration.new(api_key: "k", timeout: 5).to_h)
      end
    end
  end
end
