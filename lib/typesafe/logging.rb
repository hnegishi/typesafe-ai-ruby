# frozen_string_literal: true

module TypeSafe
  # Logging helpers. The client logs request summaries at info and full headers and bodies
  # at debug. Credential headers are redacted; bodies are not, so keep debug logging out of
  # production if state contains sensitive data.
  module Logging
    PROGNAME = "typesafe"
    REDACTED = "[REDACTED]"
    REDACTED_HEADERS = %w[authorization proxy-authorization x-api-key].freeze

    module_function

    def log?(config, severity)
      !config.logger.nil? && config.logger_severity <= severity
    end

    def info(config, &)
      config.logger.info(PROGNAME, &) if log?(config, Logger::INFO)
    end

    def debug(config, &)
      config.logger.debug(PROGNAME, &) if log?(config, Logger::DEBUG)
    end

    # A copy of the headers with credential values replaced.
    def redact_headers(headers)
      headers.to_h do |name, value|
        [name, REDACTED_HEADERS.include?(name.to_s.downcase) ? REDACTED : value]
      end
    end

    def format_headers(headers)
      redact_headers(headers).map { |name, value| "#{name}: #{value}" }.join(", ")
    end
  end
end
