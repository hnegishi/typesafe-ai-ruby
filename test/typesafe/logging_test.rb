# frozen_string_literal: true

require File.expand_path("../test_helper", __dir__)

module TypeSafe
  class LoggingTest < Test::Unit::TestCase
    def config(level, logger: Logger.new(StringIO.new))
      Configuration.new(api_key: "k", logger: logger, log_level: level).resolve(env: {})
    end

    should "redact credential headers regardless of case" do
      redacted = Logging.redact_headers("Authorization" => "Bearer k", "X-API-KEY" => "k", "Accept" => "json")
      assert_equal({ "Authorization" => "[REDACTED]", "X-API-KEY" => "[REDACTED]", "Accept" => "json" }, redacted)
      assert_equal "Authorization: [REDACTED], Accept: json",
                   Logging.format_headers("Authorization" => "Bearer k", "Accept" => "json")
    end

    should "only log at or above the configured level" do
      io = StringIO.new
      logger = Logger.new(io)
      Logging.info(config(:warn, logger: logger)) { "info hidden" }
      Logging.debug(config(:info, logger: logger)) { "debug hidden" }
      Logging.info(config(:info, logger: logger)) { "info shown" }
      Logging.debug(config(:debug, logger: logger)) { "debug shown" }
      assert_no_match(/hidden/, io.string)
      assert_match(/info shown/, io.string)
      assert_match(/debug shown/, io.string)
    end

    should "respect the level even when the logger itself is more verbose" do
      io = StringIO.new
      logger = Logger.new(io)
      logger.level = Logger::DEBUG
      Logging.debug(config(:warn, logger: logger)) { "debug hidden" }
      assert_empty io.string
    end
  end
end
