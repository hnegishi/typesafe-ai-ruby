# frozen_string_literal: true

module TypeSafe
  # Per-call overrides accepted by Client#system_one and Resources::Models#list.
  class RequestOptions
    KEYS = %i[timeout headers extra_body retry_policy danger_zone].freeze

    # Timeout per attempt in seconds for this call only.
    attr_reader :timeout
    # Additional headers for this call only.
    attr_reader :headers
    # Extra top-level body fields, shallow-merged last-write-wins.
    attr_reader :extra_body
    # Retry policy override for this call only: a RetryPolicy, or a Hash applied on the client policy.
    attr_reader :retry_policy
    # Experimental features to turn on for this call: :images and/or :long_context.
    attr_reader :danger_zone

    # Coerce nil, a Hash, or a RequestOptions. A danger_zone given separately is merged in.
    def self.from(options, danger_zone: nil)
      result = case options
               when RequestOptions then options
               when nil then new
               when Hash then new(**options.transform_keys(&:to_sym))
               else raise ArgumentError, "request_options must be a Hash, got #{options.class}"
               end
      danger_zone.nil? ? result : result.with_danger_zone(danger_zone)
    end

    # A copy with additional danger zones turned on.
    def with_danger_zone(zones)
      self.class.new(timeout: timeout, headers: headers, extra_body: extra_body, retry_policy: retry_policy,
                     danger_zone: danger_zone + Util.danger_zones(zones))
    end

    def initialize(timeout: nil, headers: nil, extra_body: nil, retry_policy: nil, danger_zone: nil)
      @timeout = validate_timeout(timeout)
      @headers = (headers || {}).each_with_object({}) { |(name, value), result| result[name.to_s] = value.to_s }
      @extra_body = validate_extra_body(extra_body)
      @retry_policy = validate_retry_policy(retry_policy)
      @danger_zone = Util.danger_zones(danger_zone).freeze
      freeze
    end

    private

    def validate_timeout(timeout)
      return nil if timeout.nil?
      return timeout if timeout.is_a?(Numeric) && timeout.finite? && timeout.positive?

      raise ArgumentError, "timeout must be a positive number of seconds, got #{timeout.inspect}"
    end

    def validate_retry_policy(retry_policy)
      return retry_policy if retry_policy.nil? || retry_policy.is_a?(RetryPolicy) || retry_policy.is_a?(Hash)

      raise ArgumentError, "retry_policy must be a RetryPolicy or a Hash, got #{retry_policy.class}"
    end

    def validate_extra_body(extra_body)
      return nil if extra_body.nil?
      raise ArgumentError, "extra_body must be a Hash, got #{extra_body.class}" unless extra_body.is_a?(Hash)

      Util.deep_stringify(extra_body)
    end
  end
end
