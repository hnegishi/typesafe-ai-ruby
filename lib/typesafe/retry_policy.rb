# frozen_string_literal: true

module TypeSafe
  # Retry configuration. Defaults match the official TypeSafe SDKs: two retries with
  # exponential backoff and jitter, honoring Retry-After, for 408, 429 and 5xx responses
  # as well as connection failures and timeouts.
  #
  # Policies are frozen values. Build one with keyword overrides, or derive a new one
  # from an existing policy with #with.
  class RetryPolicy
    DEFAULT_HTTP_STATUSES = ([408, 429] + (500..599).to_a).freeze

    # Maximum retries after the initial attempt; 0 disables retries.
    attr_reader :max_retries
    # First backoff delay in seconds, doubled each attempt up to backoff_max.
    attr_reader :backoff_initial
    # Maximum backoff delay in seconds.
    attr_reader :backoff_max
    # Fraction of each backoff delay randomly subtracted, from 0 to 1.
    attr_reader :backoff_jitter
    # HTTP status codes that are retried.
    attr_reader :http_statuses
    # Whether to honor Retry-After and retry-after-ms response headers.
    attr_reader :respect_retry_after
    # Maximum server-requested delay in seconds; longer delays fall back to backoff.
    attr_reader :max_retry_after
    # Whether to retry APIConnectionError.
    attr_reader :api_connection_error
    # Whether to retry APITimeoutError.
    attr_reader :api_timeout_error
    # Total budget in seconds per call including delays; nil disables the limit.
    attr_reader :timeout

    # Coerce nil, a Hash of overrides, or a RetryPolicy into a RetryPolicy.
    # Hash overrides are applied on top of +base+ (the SDK defaults unless given).
    def self.from(value, base: nil)
      base ||= DEFAULT
      case value
      when nil then base
      when RetryPolicy then value
      when Hash then base.with(**value.transform_keys(&:to_sym))
      else raise ArgumentError, "retry_policy must be a RetryPolicy or a Hash, got #{value.class}"
      end
    end

    def initialize(max_retries: 2, backoff_initial: 0.5, backoff_max: 5.0, backoff_jitter: 0.25,
                   http_statuses: DEFAULT_HTTP_STATUSES, respect_retry_after: true, max_retry_after: 60.0,
                   api_connection_error: true, api_timeout_error: true, timeout: 30.0)
      @max_retries = non_negative_integer(:max_retries, max_retries)
      @backoff_initial = non_negative_number(:backoff_initial, backoff_initial)
      @backoff_max = non_negative_number(:backoff_max, backoff_max)
      @backoff_jitter = fraction(:backoff_jitter, backoff_jitter)
      @http_statuses = http_statuses.to_a.map(&:to_i).freeze
      @respect_retry_after = respect_retry_after ? true : false
      @max_retry_after = non_negative_number(:max_retry_after, max_retry_after)
      @api_connection_error = api_connection_error ? true : false
      @api_timeout_error = api_timeout_error ? true : false
      @timeout = timeout.nil? ? nil : non_negative_number(:timeout, timeout)
      freeze
    end

    def to_h
      {
        max_retries: max_retries, backoff_initial: backoff_initial, backoff_max: backoff_max,
        backoff_jitter: backoff_jitter, http_statuses: http_statuses, respect_retry_after: respect_retry_after,
        max_retry_after: max_retry_after, api_connection_error: api_connection_error,
        api_timeout_error: api_timeout_error, timeout: timeout
      }
    end

    # A copy of this policy with the given fields replaced.
    def with(**overrides)
      self.class.new(**to_h, **overrides)
    end

    def ==(other)
      other.is_a?(RetryPolicy) && to_h == other.to_h
    end
    alias eql? ==

    def hash
      to_h.hash
    end

    def retry_status?(status)
      http_statuses.include?(status)
    end

    # Whether a connection-level error should be retried.
    def retry_error?(error)
      case error
      when APITimeoutError then api_timeout_error
      when APIConnectionError then api_connection_error
      else false
      end
    end

    # Seconds to wait before the retry following +attempt+ (0 for the first retry).
    # Uses the server's Retry-After when present and within max_retry_after, otherwise
    # capped exponential backoff with jitter.
    def delay_for(attempt, headers: nil, random: Kernel)
      if respect_retry_after && headers
        server_delay = Util.parse_retry_after(headers)
        return server_delay if server_delay && server_delay <= max_retry_after
      end

      exponential = [backoff_initial * (2**attempt), backoff_max].min
      exponential * (1 - (random.rand * backoff_jitter))
    end

    private

    def non_negative_integer(name, value)
      return value if value.is_a?(Integer) && value >= 0

      raise ArgumentError, "#{name} must be a non-negative Integer, got #{value.inspect}"
    end

    def non_negative_number(name, value)
      return value if value.is_a?(Numeric) && value.finite? && value >= 0

      raise ArgumentError, "#{name} must be a non-negative number, got #{value.inspect}"
    end

    def fraction(name, value)
      return value if value.is_a?(Numeric) && value >= 0 && value <= 1

      raise ArgumentError, "#{name} must be between 0 and 1, got #{value.inspect}"
    end
  end

  RetryPolicy::DEFAULT = RetryPolicy.new
end
