# frozen_string_literal: true

module TypeSafe
  module Questions
    # Locates what its instructions describe in an image. The answer is a bounding box.
    # Box questions need an image in the request, the :images danger zone, and Jev 1.14
    # (model "jev-preview" or "jev-1.14.0"). Box takes no criteria.
    #
    # For example:
    #   TypeSafe::Box.new(instructions: "the coffee mug in `photo`")
    class Box < Question
      TYPE = "box"

      def initialize(instructions: nil)
        super(TYPE, instructions: instructions, criteria: nil)
      end
    end
  end
end
