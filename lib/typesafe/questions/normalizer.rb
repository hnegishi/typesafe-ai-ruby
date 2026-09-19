# frozen_string_literal: true

module TypeSafe
  module Questions
    # Turns user-supplied state and questions into the wire format, validating the obvious
    # mistakes before a request is sent.
    module Normalizer
      TYPES = {
        Noul::TYPE => Noul, Choice::TYPE => Choice, Score::TYPE => Score
      }.freeze

      module_function

      def state(state)
        raise ValidationError, "state must not be nil; pass a String, Hash, or Array" if state.nil?

        value = Util.deep_stringify(state)
        return value if value.is_a?(String) || value.is_a?(Hash) || value.is_a?(Array)

        raise ValidationError, "state must be a String, Hash, or Array, got #{state.class}"
      end

      # Questions in wire format.
      def questions(questions)
        raise ValidationError, "questions must be a non-empty Hash" unless questions.is_a?(Hash) && !questions.empty?

        questions.each_with_object({}) do |(name, question), result|
          key = Util.stringify_key(name)
          raise ValidationError, "question names must not be blank" if key.strip.empty?

          result[key] = question(question, key)
        end
      end

      def question(question, name)
        case question
        when Question then question.to_h
        when Hash then raw_question(question, name)
        else
          raise ValidationError,
                "question #{name.inspect} must be a TypeSafe::Noul, Choice, Score, or a Hash with a \"type\" key"
        end
      end

      # Validate a raw Hash question. Known types get the same checks as the typed classes;
      # unknown types and extra keys pass through untouched so new API fields work immediately.
      def raw_question(hash, name)
        wire = Util.deep_stringify(hash)
        type = wire["type"]
        unless type.is_a?(String) && !type.empty?
          raise ValidationError,
                "question #{name.inspect} is missing a \"type\""
        end

        klass = TYPES[type]
        wire["criteria"] = klass.normalize_criteria(wire["criteria"]) if klass && requires_criteria?(klass, wire)
        wire
      end

      def requires_criteria?(klass, wire)
        klass != Noul || wire.key?("criteria")
      end
    end
  end
end
