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
require_relative "typesafe/logging"
require_relative "typesafe/instrumentation"
require_relative "typesafe/configuration"
require_relative "typesafe/retry_policy"
require_relative "typesafe/request_options"
require_relative "typesafe/questions/question"
require_relative "typesafe/questions/noul"
require_relative "typesafe/questions/choice"
require_relative "typesafe/questions/score"
require_relative "typesafe/questions/normalizer"
require_relative "typesafe/http/request"
require_relative "typesafe/http/response"
require_relative "typesafe/http/connection_manager"
require_relative "typesafe/http/net_http_transport"
require_relative "typesafe/http/retrier"
require_relative "typesafe/http/requestor"
require_relative "typesafe/responses/reader"
require_relative "typesafe/responses/usage"
require_relative "typesafe/responses/answer"
require_relative "typesafe/responses/system_one_response"
require_relative "typesafe/responses/list_models_response"
require_relative "typesafe/resources/models"
require_relative "typesafe/client"

# Ruby client for the TypeSafe AI System One API.
#
# See https://docs.typesafe.ai/ for the HTTP API this gem wraps.
module TypeSafe
  Noul = Questions::Noul
  Choice = Questions::Choice
  Score = Questions::Score

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

    # Build a yes/no question.
    #
    # For example:
    #   TypeSafe.noul("Is this spam?", true: "Unsolicited advertising", false: "A real conversation")
    def noul(instructions = nil, criteria = nil, **named)
      Noul.new(instructions: instructions, criteria: merge_criteria(criteria, named))
    end

    # Build a choice question.
    #
    # For example:
    #   TypeSafe.choice("What is the tone?", calm: nil, angry: "Shouting or threats")
    def choice(instructions = nil, criteria = nil, **named)
      Choice.new(instructions: instructions, criteria: merge_criteria(criteria, named) || {})
    end

    # Build a score question.
    #
    # For example:
    #   TypeSafe.score("How urgent is this?", ["can wait", "this week", "today"])
    def score(instructions = nil, criteria = nil)
      Score.new(instructions: instructions, criteria: criteria)
    end

    private

    def merge_criteria(positional, named)
      return positional if named.empty?
      raise ArgumentError, "pass criteria either positionally or as keywords, not both" unless positional.nil?

      named
    end
  end
end
