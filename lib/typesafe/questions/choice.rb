# frozen_string_literal: true

module TypeSafe
  module Questions
    # Picks one option from a set you define. The answer carries the chosen option,
    # a probability per option, and a confidence.
    #
    # For example:
    #   TypeSafe::Choice.new(
    #     instructions: "What is the tone?",
    #     criteria: { calm: nil, frustrated: nil, angry: "Shouting, threats, or profanity" }
    #   )
    class Choice < Question
      TYPE = "choice"

      def initialize(criteria:, instructions: nil)
        super(TYPE, instructions: instructions, criteria: self.class.normalize_criteria(criteria))
      end

      def self.normalize_criteria(criteria)
        raise ValidationError, "Choice criteria must be a non-empty Hash of option => description" unless
          criteria.is_a?(Hash) && !criteria.empty?

        criteria.each_with_object({}) do |(key, value), result|
          name = Util.stringify_key(key)
          raise ValidationError, "Choice option names must not be blank" if name.strip.empty?

          result[name] = value.nil? ? nil : Util.deep_stringify(value)
        end
      end
    end
  end
end
