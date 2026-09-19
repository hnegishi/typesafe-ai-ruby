# frozen_string_literal: true

module TypeSafe
  module HTTP
    # Builds requests from a Configuration, sends them through a transport, logs them,
    # and turns non-2xx responses into APIErrors.
    class Requestor
      PROTECTED_HEADERS = [
        Constants::Headers::AUTHORIZATION, Constants::Headers::ACCEPT, Constants::Headers::USER_AGENT,
        Constants::Headers::SDK, Constants::Headers::RUNTIME, Constants::Headers::RETRY_COUNT
      ].map(&:downcase).freeze

      attr_reader :config, :transport

      def initialize(config, transport: nil)
        @config = config
        @transport = transport || config.transport || NetHTTPTransport.new
      end

      # A successful response.
      def post(path, body:, options: RequestOptions.new)
        execute(build_request(:post, path, body: body, options: options))
      end

      # A successful response.
      def get(path, options: RequestOptions.new)
        execute(build_request(:get, path, options: options))
      end

      def close
        transport.close if transport.respond_to?(:close)
      end

      private

      def execute(request)
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        response = transport.call(request)
        log_response(request, response, started)
        raise APIError.from_response(response) unless response.success?

        response
      end

      def build_request(method, path, body: nil, options: RequestOptions.new)
        encoded = body.nil? ? nil : JSON.generate(body)
        Request.new(
          method: method,
          uri: URI.parse("#{config.base_url}#{path}"),
          headers: build_headers(options.headers, body: encoded),
          body: encoded,
          timeout: options.timeout || config.timeout
        )
      end

      def build_headers(extra, body:)
        headers = strip_protected(config.headers).merge(strip_protected(extra))
        headers[Constants::Headers::AUTHORIZATION] = "Bearer #{config.api_key}"
        headers[Constants::Headers::ACCEPT] = Constants::JSON_CONTENT_TYPE
        headers[Constants::Headers::USER_AGENT] = sdk_identifier
        headers[Constants::Headers::SDK] = sdk_identifier
        headers[Constants::Headers::RUNTIME] = Util.runtime
        headers[Constants::Headers::CONTENT_TYPE] = Constants::JSON_CONTENT_TYPE if body
        headers
      end

      def strip_protected(headers)
        headers.reject { |name, _| PROTECTED_HEADERS.include?(name.downcase) }
      end

      def sdk_identifier
        "#{Constants::SDK_NAME}/#{VERSION}"
      end

      def log_response(request, response, started)
        return unless config.logger && config.logger_severity <= Logger::INFO

        elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
        config.logger.info("typesafe") do
          "#{request.endpoint} -> #{response.status} (#{elapsed}ms) request_id=#{response.request_id || "-"}"
        end
      end
    end
  end
end
