# frozen_string_literal: true

module TypeSafe
  module Responses
    # Token counts for a request, when reported by the API.
    class Usage
      attr_reader :input_tokens, :output_tokens

      def self.from_hash(hash, path = "usage")
        data = Reader.hash!(hash, path)
        new(
          input_tokens: Reader.optional_integer(data["input_tokens"], "#{path}.input_tokens"),
          output_tokens: Reader.optional_integer(data["output_tokens"], "#{path}.output_tokens")
        )
      end

      def initialize(input_tokens: nil, output_tokens: nil)
        @input_tokens = input_tokens
        @output_tokens = output_tokens
        freeze
      end

      def to_h
        { "input_tokens" => input_tokens, "output_tokens" => output_tokens }
      end

      def ==(other)
        other.is_a?(Usage) && to_h == other.to_h
      end
      alias eql? ==

      def hash
        to_h.hash
      end
    end
  end
end
