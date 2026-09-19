# frozen_string_literal: true

module TypeSafe
  module HTTP
    # Builds requests from a Configuration, sends them through a transport with retries,
    # logs them, and turns non-2xx responses into APIErrors.
    class Requestor
      PROTECTED_HEADERS = [
        Constants::Headers::AUTHORIZATION, Constants::Headers::ACCEPT, Constants::Headers::USER_AGENT,
        Constants::Headers::SDK, Constants::Headers::RUNTIME, Constants::Headers::RETRY_COUNT
      ].map(&:downcase).freeze

      attr_reader :config, :transport

      # sleeper and clock exist so tests can drive the retry loop without waiting.
      def initialize(config, transport: nil, sleeper: nil, clock: nil)
        @config = config
        @transport = transport || config.transport || NetHTTPTransport.new
        @sleeper = sleeper
        @clock = clock
      end

      # Send a POST and return the successful response.
      def post(path, body:, options: RequestOptions.new)
        execute(build_request(:post, path, body: body, options: options), options)
      end

      # Send a GET and return the successful response.
      def get(path, options: RequestOptions.new)
        execute(build_request(:get, path, options: options), options)
      end

      def close
        transport.close if transport.respond_to?(:close)
      end

      private

      def execute(request, options)
        call = CallState.new(request)
        Instrumentation.notify(:request_begin, call.begin_event)
        response = retrier_for(options, call).run do |attempt|
          send_once(attempt.zero? ? request : request.with_headers(Constants::Headers::RETRY_COUNT => attempt.to_s))
        end
        Instrumentation.notify(:request_end, call.end_event(response: response))
        response
      rescue APIError, APIConnectionError => e
        Instrumentation.notify(:request_end, call.end_event(error: e))
        raise
      end

      def retrier_for(options, call)
        on_retry = lambda do |error, attempt, delay|
          call.retried!
          log_retry(error, attempt, delay)
        end
        Retrier.new(retry_policy_for(options), sleeper: @sleeper, clock: @clock, on_retry: on_retry)
      end

      # Bookkeeping for one client call across its attempts, feeding the instrumentation events.
      class CallState
        attr_reader :begin_event

        def initialize(request)
          @request = request
          @started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          @num_retries = 0
          @begin_event = Instrumentation::RequestBeginEvent.new(method: request.method, path: request.uri.path)
        end

        def retried!
          @num_retries += 1
        end

        def end_event(response: nil, error: nil)
          status = response&.status || (error.status if error.is_a?(APIError))
          request_id = response&.request_id || (error.request_id if error.is_a?(APIError))
          Instrumentation::RequestEndEvent.new(
            method: @request.method, path: @request.uri.path, http_status: status,
            duration: Process.clock_gettime(Process::CLOCK_MONOTONIC) - @started,
            num_retries: @num_retries, request_id: request_id, error: error, user_data: @begin_event.user_data
          )
        end
      end

      def send_once(request)
        log_request(request)
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        response = transport.call(request)
        log_response(request, response, started)
        raise APIError.from_response(response) unless response.success?

        response
      end

      def retry_policy_for(options)
        RetryPolicy.from(options.retry_policy, base: config.retry_policy)
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

      def log_request(request)
        Logging.debug(config) do
          "-> #{request.endpoint} headers={#{Logging.format_headers(request.headers)}} body=#{request.body.inspect}"
        end
      end

      def log_response(request, response, started)
        elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
        Logging.info(config) do
          "#{request.endpoint} -> #{response.status} (#{elapsed}ms) request_id=#{response.request_id || "-"}"
        end
        Logging.debug(config) do
          "<- #{response.status} headers={#{Logging.format_headers(response.headers)}} body=#{response.body.inspect}"
        end
      end

      def log_retry(error, attempt, delay)
        Logging.info(config) do
          "retry #{attempt + 1} in #{delay.round(3)}s after #{error.class.name.split("::").last}: #{error.message}"
        end
      end
    end
  end
end
