# frozen_string_literal: true

require "time"

module TypeSafe
  # Internal helpers shared across the gem. Not part of the public API.
  module Util
    RETRY_AFTER_MS_HEADER = "retry-after-ms"
    RETRY_AFTER_HEADER = "retry-after"
    NUMERIC = /\A\d+(?:\.\d+)?\z/

    module_function

    # True for nil or whitespace-only strings.
    def blank?(value)
      value.nil? || (value.respond_to?(:strip) && value.strip.empty?)
    end

    # Read an environment variable, treating blank values as unset.
    def env_value(env, name)
      value = env[name]
      blank?(value) ? nil : value.strip
    end

    # Headers with lower-cased names and string values.
    def normalize_headers(headers)
      (headers || {}).each_with_object({}) do |(name, value), result|
        result[name.to_s.downcase] = value.is_a?(Array) ? value.join(", ") : value.to_s
      end
    end

    # Convert a value into plain JSON-compatible Ruby: string keys, no symbols, finite floats.
    # Objects responding to as_json are converted through it. Anything else raises.
    def deep_stringify(value)
      case value
      when String, Integer, true, false, nil then value
      when Symbol then value.to_s
      when Float then finite_float(value)
      when Hash, Array then stringify_container(value)
      else convert_object(value)
      end
    end

    def stringify_container(value)
      return value.map { |v| deep_stringify(v) } if value.is_a?(Array)

      value.each_with_object({}) { |(k, v), h| h[stringify_key(k)] = deep_stringify(v) }
    end

    def finite_float(value)
      raise ValidationError, "non-finite Float #{value} cannot be encoded as JSON" unless value.finite?

      value
    end

    def stringify_key(key)
      case key
      when String then key
      when Symbol, Integer, true, false then key.to_s
      else raise ValidationError, "cannot use #{key.class} as a JSON object key"
      end
    end

    def convert_object(value)
      unless value.respond_to?(:as_json)
        raise ValidationError,
              "cannot encode #{value.class} as JSON; pass a String, Hash, Array, or an object responding to as_json"
      end

      converted = value.as_json
      raise ValidationError, "#{value.class}#as_json returned itself and cannot be encoded" if converted.equal?(value)

      deep_stringify(converted)
    end

    # Parse retry-after-ms (preferred) or Retry-After (seconds or HTTP-date) into seconds.
    def parse_retry_after(headers)
      normalized = normalize_headers(headers)
      ms = normalized[RETRY_AFTER_MS_HEADER]
      return ms.to_f / 1000.0 if ms&.match?(NUMERIC)

      raw = normalized[RETRY_AFTER_HEADER]
      return nil if raw.nil?
      return raw.to_f if raw.match?(NUMERIC)

      delta = Time.httpdate(raw) - Time.now
      delta.positive? ? delta : 0.0
    rescue ArgumentError
      nil
    end

    # A short human-readable rendering of an error body for exception messages.
    def summarize_body(body, limit: 200)
      text = case body
             when nil then ""
             when Hash then summarize_hash(body)
             when String then body.strip
             else JSON.generate(body)
             end
      text.length > limit ? "#{text[0, limit]}..." : text
    end

    def summarize_hash(body)
      error = body["error"]
      return error if error.is_a?(String)
      return error["message"] if error.is_a?(Hash) && error["message"].is_a?(String)

      %w[message detail].each do |key|
        value = body[key]
        return value.is_a?(String) ? value : JSON.generate(value) if value
      end
      JSON.generate(body)
    end

    # The runtime identifier sent in X-TypeSafe-Runtime.
    def runtime
      "ruby/#{RUBY_VERSION} (#{RUBY_PLATFORM})"
    end
  end

  # A Hash whose string keys can also be looked up with symbols.
  class IndifferentHash < Hash
    def self.from(hash)
      new.tap { |result| hash.each { |key, value| result[key] = value } }
    end

    def [](key)
      super(convert(key))
    end

    def []=(key, value)
      super(convert(key), value)
    end

    def fetch(key, ...)
      super(convert(key), ...)
    end

    def key?(key)
      super(convert(key))
    end
    alias has_key? key?
    alias include? key?
    alias member? key?

    def dig(key, *rest)
      super(convert(key), *rest)
    end

    private

    def convert(key)
      key.is_a?(Symbol) ? key.to_s : key
    end
  end
end
