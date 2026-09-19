# frozen_string_literal: true

module TypeSafe
  module HTTP
    # Default transport built on Net::HTTP with keep-alive connections managed per thread.
    #
    # Any object responding to call(request) and returning a Response can replace it,
    # which is how tests stub the network and how alternative HTTP stacks can be plugged in.
    class NetHTTPTransport
      TIMEOUT_ERRORS = [Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout, Timeout::Error].freeze
      CONNECTION_ERRORS = [
        SocketError, SystemCallError, IOError, EOFError, OpenSSL::SSL::SSLError,
        Net::HTTPBadResponse, Net::ProtocolError
      ].freeze

      def initialize
        @managers = {}
        @mutex = Mutex.new
      end

      def call(request)
        manager = connection_manager
        http = manager.connection_for(request.uri, timeout: request.timeout)
        wrap_response(http.request(build_request(request)), request)
      rescue *TIMEOUT_ERRORS => e
        manager&.discard(request.uri)
        raise timeout_error(request, e)
      rescue *CONNECTION_ERRORS => e
        manager&.discard(request.uri)
        raise connection_error(request, e)
      end

      # Close every connection held for any thread.
      def close
        @mutex.synchronize do
          @managers.each_value(&:clear)
          @managers.clear
        end
      end

      # The manager for the calling thread, creating it on first use and releasing
      # managers whose threads have finished.
      def connection_manager
        @mutex.synchronize do
          @managers.delete_if { |thread, manager| !thread.alive? && (manager.clear || true) }
          @managers[Thread.current] ||= ConnectionManager.new
        end
      end

      private

      def timeout_error(request, error)
        APITimeoutError.new("#{request.endpoint} timed out after #{request.timeout}s (#{error.class})",
                            timeout: request.timeout)
      end

      def connection_error(request, error)
        APIConnectionError.new("#{request.endpoint} failed: #{error.class}: #{error.message}")
      end

      def wrap_response(raw, request)
        Response.new(status: raw.code.to_i, headers: raw.each_header.to_h, body: raw.body, request: request)
      end

      def build_request(request)
        klass = request.method == :get ? Net::HTTP::Get : Net::HTTP::Post
        raw = klass.new(request.uri.request_uri)
        request.headers.each { |name, value| raw[name] = value }
        raw.body = request.body if request.body
        raw
      end
    end
  end
end
