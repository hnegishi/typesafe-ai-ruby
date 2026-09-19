# frozen_string_literal: true

module TypeSafe
  module Responses
    # Raised internally while parsing a response body; converted to APIResponseValidationError.
    class InvalidField < StandardError
      attr_reader :field_path

      def initialize(field_path, message)
        @field_path = field_path
        super("#{field_path}: #{message}")
      end
    end

    # Typed accessors for JSON values that record the dotted path of any violation.
    module Reader
      module_function

      # Build the public error for an InvalidField raised while parsing a response.
      def validation_error(error, response, json)
        APIResponseValidationError.new(
          "Invalid response body: #{error.message}",
          field_path: error.field_path,
          status: response.status,
          body: json || response.body,
          headers: response.headers,
          endpoint: response.request&.endpoint
        )
      end

      def hash!(value, path)
        raise InvalidField.new(path, "expected an object, got #{value.class}") unless value.is_a?(Hash)

        value
      end

      def string!(value, path)
        raise InvalidField.new(path, "expected a string, got #{value.class}") unless value.is_a?(String)

        value
      end

      def number!(value, path)
        raise InvalidField.new(path, "expected a number, got #{value.class}") unless value.is_a?(Numeric)
        raise InvalidField.new(path, "expected a finite number") if value.is_a?(Float) && !value.finite?

        value.to_f
      end

      def optional_integer(value, path)
        return nil if value.nil?
        raise InvalidField.new(path, "expected an integer, got #{value.class}") unless value.is_a?(Integer)

        value
      end

      def optional_string(value, path)
        value.nil? ? nil : string!(value, path)
      end

      def number_map!(value, path)
        hash!(value, path).each_with_object({}) { |(key, v), result| result[key.to_s] = number!(v, "#{path}.#{key}") }
      end

      # Convert "0", "1", ... keys into Integers.
      def integer_keyed(hash, path)
        hash.each_with_object({}) do |(key, value), result|
          raise InvalidField.new("#{path}.#{key}", "expected an integer level key") unless key.match?(/\A\d+\z/)

          result[key.to_i] = value
        end
      end
    end
  end
end
