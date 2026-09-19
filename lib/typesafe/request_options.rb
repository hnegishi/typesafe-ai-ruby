# frozen_string_literal: true

module TypeSafe
  # Per-call overrides accepted by Client#system_one and Resources::Models#list.
  class RequestOptions
    KEYS = %i[timeout headers extra_body retry_policy].freeze

    # Timeout per attempt in seconds for this call only.
    attr_reader :timeout
    # Additional headers for this call only.
    attr_reader :headers
    # Extra top-level body fields, shallow-merged last-write-wins.
    attr_reader :extra_body
    # Retry policy override for this call only.
    attr_reader :retry_policy

    def self.from(options)
      case options
      when RequestOptions then options
      when nil then new
      when Hash then new(**options.transform_keys(&:to_sym))
      else raise ArgumentError, "request_options must be a Hash, got #{options.class}"
      end
    end

    def initialize(timeout: nil, headers: nil, extra_body: nil, retry_policy: nil)
      @timeout = validate_timeout(timeout)
      @headers = (headers || {}).each_with_object({}) { |(name, value), result| result[name.to_s] = value.to_s }
      @extra_body = validate_extra_body(extra_body)
      @retry_policy = retry_policy
      freeze
    end

    private

    def validate_timeout(timeout)
      return nil if timeout.nil?
      return timeout if timeout.is_a?(Numeric) && timeout.finite? && timeout.positive?

      raise ArgumentError, "timeout must be a positive number of seconds, got #{timeout.inspect}"
    end

    def validate_extra_body(extra_body)
      return nil if extra_body.nil?
      raise ArgumentError, "extra_body must be a Hash, got #{extra_body.class}" unless extra_body.is_a?(Hash)

      Util.deep_stringify(extra_body)
    end
  end
end
