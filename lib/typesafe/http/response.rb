# frozen_string_literal: true

module TypeSafe
  module HTTP
    # A raw HTTP response: status, lower-cased headers, body text, and the request that produced it.
    class Response
      attr_reader :status, :headers, :body, :request

      def initialize(status:, headers:, body:, request: nil)
        @status = status
        @headers = Util.normalize_headers(headers).freeze
        @body = body.to_s
        @request = request
        @json = nil
        @json_parsed = false
      end

      # Case-insensitive header lookup.
      def [](name)
        headers[name.to_s.downcase]
      end

      # The x-typesafe-request-id header.
      def request_id
        self[Constants::Headers::REQUEST_ID]
      end

      def success?
        (200..299).cover?(status)
      end

      # The parsed JSON body, or nil when the body is not valid JSON.
      def json
        return @json if @json_parsed

        @json_parsed = true
        @json = body.empty? ? nil : JSON.parse(body)
      rescue JSON::ParserError
        @json = nil
      end

      # Server-requested wait in seconds, from retry-after-ms or Retry-After.
      def retry_after
        Util.parse_retry_after(headers)
      end
    end
  end
end
