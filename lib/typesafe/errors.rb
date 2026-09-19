# frozen_string_literal: true

module TypeSafe
  # Base class for every error raised by this gem.
  class Error < StandardError; end

  # Raised when the client cannot be configured, for example when the API key is missing.
  class ConfigurationError < Error; end

  # Raised before a request is sent when questions or state are malformed.
  class ValidationError < Error; end

  # An unsuccessful HTTP response, carrying the status, decoded body, headers and endpoint.
  class APIError < Error
    # HTTP status code.
    attr_reader :status
    # JSON body, plain text, or nil for an empty body.
    attr_reader :body
    # Response headers with lower-cased names.
    attr_reader :headers
    # Request method and URL without credentials, e.g. "POST https://api.typesafe.ai/v1/systemone".
    attr_reader :endpoint

    def initialize(message = nil, status: nil, body: nil, headers: {}, endpoint: nil)
      @status = status
      @body = body
      @headers = Util.normalize_headers(headers)
      @endpoint = endpoint
      super(message || self.class.build_message(status: status, body: body, endpoint: endpoint, request_id: request_id))
    end

    # The x-typesafe-request-id response header.
    def request_id
      @headers[Constants::Headers::REQUEST_ID]
    end

    # Build the error subclass matching the response status.
    def self.from_response(response)
      class_for_status(response.status).new(
        status: response.status,
        body: response.json || (response.body.empty? ? nil : response.body),
        headers: response.headers,
        endpoint: response.request&.endpoint
      )
    end

    def self.class_for_status(status)
      STATUS_CLASSES.fetch(status) { (500..599).cover?(status) ? InternalServerError : APIError }
    end

    def self.build_message(status:, body:, endpoint:, request_id:)
      head = [status && "[#{status}]", endpoint].compact.join(" ")
      summary = Util.summarize_body(body)
      message = [head, summary].reject(&:empty?).join(": ")
      message = "API request failed" if message.empty?
      request_id ? "#{message} (request_id: #{request_id})" : message
    end
  end

  # The request was invalid (400).
  class BadRequestError < APIError; end
  # Authentication failed (401).
  class AuthenticationError < APIError; end
  # Access was denied (403).
  class PermissionDeniedError < APIError; end
  # The resource was not found (404).
  class NotFoundError < APIError; end
  # The request failed server-side validation (422).
  class UnprocessableEntityError < APIError; end
  # The server failed to process the request (5xx).
  class InternalServerError < APIError; end
  # TypeSafe is temporarily overloaded (529).
  class OverloadedError < InternalServerError; end

  # The rate limit was exceeded (429).
  class RateLimitError < APIError
    # The wait requested by the server in seconds, from retry-after-ms or Retry-After.
    def retry_after
      Util.parse_retry_after(headers)
    end
  end

  # A successful HTTP response whose body was missing or structurally invalid required data.
  class APIResponseValidationError < APIError
    # Dotted path to the offending field, such as "answers.tone.confidence".
    attr_reader :field_path

    def initialize(message = nil, field_path:, **options)
      @field_path = field_path
      super(message || "Invalid response field #{field_path}", **options)
    end
  end

  APIError::STATUS_CLASSES = {
    400 => BadRequestError,
    401 => AuthenticationError,
    403 => PermissionDeniedError,
    404 => NotFoundError,
    422 => UnprocessableEntityError,
    429 => RateLimitError,
    529 => OverloadedError
  }.freeze

  # A request failed without an HTTP response.
  class APIConnectionError < Error; end

  # A request exceeded its configured timeout.
  class APITimeoutError < APIConnectionError
    # The timeout applied to the request, in seconds.
    attr_reader :timeout

    def initialize(message = nil, timeout: nil)
      @timeout = timeout
      super(message || "Request timed out after #{timeout}s")
    end
  end
end
