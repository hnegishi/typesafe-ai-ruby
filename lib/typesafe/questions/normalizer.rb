# frozen_string_literal: true

module TypeSafe
  module Questions
    # Turns user-supplied state and questions into the wire format, validating the obvious
    # mistakes before a request is sent.
    module Normalizer
      TYPES = {
        Noul::TYPE => Noul, Choice::TYPE => Choice, Score::TYPE => Score, Box::TYPE => Box
      }.freeze

      module_function

      # Images found in the state are appended to +assets+ and replaced by their references.
      def state(state, assets: nil)
        raise ValidationError, "state must not be nil; pass a String, Hash, or Array" if state.nil?

        value = Util.deep_stringify(state, assets: assets)
        return value if value.is_a?(String) || value.is_a?(Hash) || value.is_a?(Array)

        raise ValidationError, "state must be a String, Hash, or Array, got #{state.class}"
      end

      # Questions in wire format.
      def questions(questions, assets: nil)
        raise ValidationError, "questions must be a non-empty Hash" unless questions.is_a?(Hash) && !questions.empty?

        questions.each_with_object({}) do |(name, question), result|
          key = Util.stringify_key(name)
          raise ValidationError, "question names must not be blank" if key.strip.empty?

          result[key] = question(question, key, assets: assets)
        end
      end

      def question(question, name, assets: nil)
        case question
        when Question
          assets&.concat(question.assets)
          question.to_h
        when Hash then raw_question(question, name, assets: assets)
        else
          raise ValidationError,
                "question #{name.inspect} must be a TypeSafe::Noul, Choice, Score, or a Hash with a \"type\" key"
        end
      end

      # Validate a raw Hash question. Known types get the same checks as the typed classes;
      # unknown types and extra keys pass through untouched so new API fields work immediately.
      def raw_question(hash, name, assets: nil)
        wire = Util.deep_stringify(hash, assets: assets)
        type = wire["type"]
        unless type.is_a?(String) && !type.empty?
          raise ValidationError,
                "question #{name.inspect} is missing a \"type\""
        end

        klass = TYPES[type]
        if klass == Box
          raise ValidationError, "question #{name.inspect}: box questions take no criteria" if wire.key?("criteria")
        elsif klass && requires_criteria?(klass, wire)
          wire["criteria"] = klass.normalize_criteria(wire["criteria"])
        end
        wire
      end

      def requires_criteria?(klass, wire)
        klass != Noul || wire.key?("criteria")
      end
    end
  end
end
