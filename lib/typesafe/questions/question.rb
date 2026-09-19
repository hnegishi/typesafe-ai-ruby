# frozen_string_literal: true

module TypeSafe
  module Questions
    # Base class for the three typed questions. Instances are immutable value objects
    # that serialize to the wire format through #to_h.
    class Question
      # "noul", "choice" or "score".
      attr_reader :type
      # What the model should decide.
      attr_reader :instructions
      # Type-specific rubric.
      attr_reader :criteria

      def initialize(type, instructions:, criteria:)
        @type = type
        @instructions = instructions.nil? ? nil : Util.deep_stringify(instructions)
        @criteria = criteria
        freeze
      end

      # The request body fragment for this question.
      def to_h
        hash = { "type" => type }
        hash["instructions"] = instructions unless instructions.nil?
        hash["criteria"] = criteria unless criteria.nil?
        hash
      end

      def to_json(*args)
        JSON.generate(to_h, *args)
      end

      def ==(other)
        other.is_a?(Question) && to_h == other.to_h
      end
      alias eql? ==

      def hash
        to_h.hash
      end

      def inspect
        "#<#{self.class.name} #{to_h.inspect}>"
      end
    end
  end
end
