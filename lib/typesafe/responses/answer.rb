# frozen_string_literal: true

module TypeSafe
  module Responses
    # Base class for answers. .from_hash dispatches on the "type" field.
    class Answer
      # "noul", "choice", "score", or an unrecognized type.
      attr_reader :type
      # The answer exactly as the API returned it, including unknown fields.
      attr_reader :raw

      def self.from_hash(hash, path)
        data = Reader.hash!(hash, path)
        type = Reader.string!(data["type"], "#{path}.type")
        klass = TYPES.fetch(type, UnknownAnswer)
        klass.parse(data, path)
      end

      def initialize(raw)
        @raw = raw.freeze
        @type = raw["type"]
      end

      # The raw answer.
      def to_h
        raw
      end

      def to_json(*args)
        JSON.generate(raw, *args)
      end

      def ==(other)
        other.class == self.class && raw == other.raw
      end
      alias eql? ==

      def hash
        raw.hash
      end

      def inspect
        "#<#{self.class.name} #{raw.inspect}>"
      end
    end

    # A yes/no answer.
    class NoulAnswer < Answer
      # Probability of yes, from 0 to 1.
      attr_reader :noul

      def self.parse(data, path)
        new(data, noul: Reader.number!(data["noul"], "#{path}.noul"))
      end

      def initialize(raw, noul:)
        @noul = noul
        super(raw)
        freeze
      end
    end

    # A selected option with its probability distribution.
    class ChoiceAnswer < Answer
      # The highest-probability option.
      attr_reader :choice
      # Probability per option.
      attr_reader :probabilities
      # Certainty derived from the distribution, from 0 to 1.
      attr_reader :confidence

      def self.parse(data, path)
        new(
          data,
          choice: Reader.string!(data["choice"], "#{path}.choice"),
          probabilities: Reader.number_map!(data["probabilities"], "#{path}.probabilities"),
          confidence: Reader.number!(data["confidence"], "#{path}.confidence")
        )
      end

      def initialize(raw, choice:, probabilities:, confidence:)
        @choice = choice
        @probabilities = IndifferentHash.from(probabilities).freeze
        @confidence = confidence
        super(raw)
        freeze
      end
    end

    # An expected score with its rubric and probability per level.
    class ScoreAnswer < Answer
      # Probability-weighted score; may fall between integer levels.
      attr_reader :score
      # Level index to description.
      attr_reader :legend
      # Probability per level index.
      attr_reader :probabilities
      # Certainty derived from the distribution, from 0 to 1.
      attr_reader :confidence

      def self.parse(data, path)
        new(
          data,
          score: Reader.number!(data["score"], "#{path}.score"),
          legend: Reader.integer_keyed(Reader.hash!(data["legend"], "#{path}.legend"), "#{path}.legend"),
          probabilities: Reader.integer_keyed(Reader.number_map!(data["probabilities"], "#{path}.probabilities"),
                                              "#{path}.probabilities"),
          confidence: Reader.number!(data["confidence"], "#{path}.confidence")
        )
      end

      def initialize(raw, score:, legend:, probabilities:, confidence:)
        @score = score
        @legend = legend.freeze
        @probabilities = probabilities.freeze
        @confidence = confidence
        super(raw)
        freeze
      end

      # Legend with the original string keys.
      def raw_legend
        raw["legend"]
      end

      # Probabilities with the original string keys.
      def raw_probabilities
        raw["probabilities"]
      end
    end

    # An answer whose type this gem does not recognize. Only #raw is available.
    class UnknownAnswer < Answer
      def self.parse(data, _path)
        new(data)
      end
    end

    Answer::TYPES = {
      "noul" => NoulAnswer, "choice" => ChoiceAnswer, "score" => ScoreAnswer
    }.freeze
  end
end
