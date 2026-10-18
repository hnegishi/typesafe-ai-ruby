# frozen_string_literal: true

module TypeSafe
  module Questions
    # A yes/no question. The answer is the probability of yes, from 0 to 1.
    #
    # For example:
    #   TypeSafe::Noul.new(
    #     instructions: "Is this message spam?",
    #     criteria: { true: "Unsolicited advertising", false: "A real conversation" }
    #   )
    class Noul < Question
      TYPE = "noul"
      KEYS = %w[true false].freeze

      def initialize(instructions: nil, criteria: nil)
        assets = []
        instructions = Util.deep_stringify(instructions, assets: assets) # collect instruction images first
        super(TYPE, instructions: instructions, criteria: self.class.normalize_criteria(criteria, assets: assets),
                    assets: assets)
      end

      def self.normalize_criteria(criteria, assets: nil)
        return nil if criteria.nil?
        raise ValidationError, "Noul criteria must be a Hash with true/false keys" unless criteria.is_a?(Hash)

        criteria.each_with_object({}) do |(key, value), result|
          name = key.to_s
          unless KEYS.include?(name)
            raise ValidationError,
                  "Noul criteria keys must be true or false, got #{key.inspect}"
          end

          result[name] = value.nil? ? nil : Util.deep_stringify(value, assets: assets)
        end
      end
    end
  end
end
