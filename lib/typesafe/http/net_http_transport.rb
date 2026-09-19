# frozen_string_literal: true

module TypeSafe
  module HTTP
    # Default transport built on Net::HTTP. Opens one connection per call.
    #
    # Any object responding to call(request) and returning a Response can replace it,
    # which is how tests stub the network and how alternative HTTP stacks can be plugged in.
    class NetHTTPTransport
      TIMEOUT_ERRORS = [Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout, Timeout::Error].freeze
      CONNECTION_ERRORS = [
        SocketError, SystemCallError, IOError, EOFError, OpenSSL::SSL::SSLError,
        Net::HTTPBadResponse, Net::ProtocolError
      ].freeze

      def call(request)
        http = build_http(request.uri, request.timeout)
        raw = http.start { |connection| connection.request(build_request(request)) }
        wrap_response(raw, request)
      rescue *TIMEOUT_ERRORS => e
        raise APITimeoutError.new("#{request.endpoint} timed out after #{request.timeout}s (#{e.class})",
                                  timeout: request.timeout)
      rescue *CONNECTION_ERRORS => e
        raise APIConnectionError, "#{request.endpoint} failed: #{e.class}: #{e.message}"
      end

      def close; end

      private

      def wrap_response(raw, request)
        Response.new(status: raw.code.to_i, headers: raw.each_header.to_h, body: raw.body, request: request)
      end

      def build_http(uri, timeout)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = timeout
        http.read_timeout = timeout
        http.write_timeout = timeout
        http
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
