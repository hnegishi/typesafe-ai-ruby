# frozen_string_literal: true

module TypeSafe
  module HTTP
    # An outgoing HTTP request: method, absolute URI, headers, encoded body and per-attempt timeout.
    class Request
      attr_reader :method, :uri, :headers, :body, :timeout

      def initialize(method:, uri:, headers:, body:, timeout:)
        @method = method
        @uri = uri
        @headers = headers.freeze
        @body = body
        @timeout = timeout
        freeze
      end

      # Method and URL without credentials, query, or fragment.
      def endpoint
        port = uri.port == uri.default_port ? "" : ":#{uri.port}"
        "#{method.to_s.upcase} #{uri.scheme}://#{uri.host}#{port}#{uri.path}"
      end

      # A copy with additional headers merged in.
      def with_headers(extra)
        self.class.new(method: method, uri: uri, headers: headers.merge(extra), body: body, timeout: timeout)
      end
    end
  end
end
