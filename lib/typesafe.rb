# frozen_string_literal: true

require "json"
require "logger"
require "net/http"
require "openssl"
require "uri"

require_relative "typesafe/version"
require_relative "typesafe/constants"
require_relative "typesafe/util"
require_relative "typesafe/errors"
require_relative "typesafe/configuration"
require_relative "typesafe/request_options"

# Ruby client for the TypeSafe AI System One API.
#
# See https://docs.typesafe.ai/ for the HTTP API this gem wraps.
module TypeSafe

  class << self
    # Global settings used by .client. Mutate through .configure.
    def configuration
      @configuration ||= Configuration.new
    end

    # Configure the default client.
    #
    # For example:
    #   TypeSafe.configure do |c|
    #     c.api_key = Rails.application.credentials.typesafe_api_key
    #     c.logger  = Rails.logger
    #   end
    def configure
      yield configuration
      reset_client!
      configuration
    end

    # The default client built from .configuration. Memoized until .configure is called again.
    def client
      @client ||= Client.new(**configuration.to_h)
    end

    # Discard the memoized default client. Mostly useful in tests.
    def reset_client!
      @client&.close
      @client = nil
    end

    # Reset global configuration and the default client. Mostly useful in tests.
    def reset!
      reset_client!
      @configuration = nil
    end

  end
end
