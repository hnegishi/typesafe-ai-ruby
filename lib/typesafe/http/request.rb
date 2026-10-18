# frozen_string_literal: true

module TypeSafe
  module HTTP
    # An outgoing HTTP request: method, absolute URI, headers, encoded body and per-attempt timeout.
    class Request
      attr_reader :method, :uri, :headers, :body, :timeout
      # What to show for the body in debug logs; multipart bodies summarize their file parts.
      attr_reader :body_summary

      def initialize(method:, uri:, headers:, body:, timeout:, body_summary: nil)
        @method = method
        @uri = uri
        @headers = headers.freeze
        @body = body
        @timeout = timeout
        @body_summary = body_summary || body
        freeze
      end

      # Method and URL without credentials, query, or fragment.
      def endpoint
        port = uri.port == uri.default_port ? "" : ":#{uri.port}"
        "#{method.to_s.upcase} #{uri.scheme}://#{uri.host}#{port}#{uri.path}"
      end

      # A copy with additional headers merged in.
      def with_headers(extra)
        self.class.new(method: method, uri: uri, headers: headers.merge(extra), body: body, timeout: timeout,
                       body_summary: body_summary)
      end
    end
  end
end
