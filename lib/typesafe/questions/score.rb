# frozen_string_literal: true

module TypeSafe
  module Questions
    # Rates the state against ordered levels. Each level's index is its score, starting at zero.
    #
    # For example:
    #   TypeSafe::Score.new(
    #     instructions: "How urgent is this?",
    #     criteria: ["Can wait", "Needs attention this week", "Needs attention today"]
    #   )
    class Score < Question
      TYPE = "score"
      MIN_LEVELS = 2

      def initialize(criteria:, instructions: nil)
        assets = []
        instructions = Util.deep_stringify(instructions, assets: assets) # collect instruction images first
        super(TYPE, instructions: instructions, criteria: self.class.normalize_criteria(criteria, assets: assets),
                    assets: assets)
      end

      def self.normalize_criteria(criteria, assets: nil)
        raise ValidationError, "Score criteria must be an Array of at least #{MIN_LEVELS} levels" unless
          criteria.is_a?(Array) && criteria.length >= MIN_LEVELS

        criteria.map do |level|
          raise ValidationError, "Score levels must not be nil" if level.nil?

          Util.deep_stringify(level, assets: assets)
        end
      end
    end
  end
end
