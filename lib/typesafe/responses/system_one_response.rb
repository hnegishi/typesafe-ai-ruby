# frozen_string_literal: true

module TypeSafe
  module Responses
    # Answers keyed by question name, with the model that answered and token usage.
    class SystemOneResponse
      # The versioned model that answered, e.g. "jev-1.13.0".
      attr_reader :model
      attr_reader :usage
      # Every answer keyed by question name.
      attr_reader :answers
      # The underlying HTTP response.
      attr_reader :http_response
      # The parsed JSON body.
      attr_reader :raw

      def self.from_http(response)
        json = response.json
        parse(json, response)
      rescue InvalidField => e
        raise Reader.validation_error(e, response, json)
      end

      def self.parse(json, response)
        data = Reader.hash!(json, "$")
        new(
          model: Reader.string!(data["model"], "model"),
          usage: Usage.from_hash(data["usage"], "usage"),
          answers: parse_answers(data["answers"]),
          http_response: response,
          raw: data
        )
      end

      def self.parse_answers(answers)
        return {} if answers.nil?

        Reader.hash!(answers, "answers").each_with_object({}) do |(name, answer), result|
          result[name] = Answer.from_hash(answer, "answers.#{name}")
        end
      end

      def initialize(model:, usage:, answers:, http_response: nil, raw: nil)
        @model = model
        @usage = usage
        @answers = IndifferentHash.from(answers).freeze
        @http_response = http_response
        @raw = raw
        freeze
      end

      # The answer for a question name.
      def [](name)
        answers[name]
      end

      # The x-typesafe-request-id header.
      def request_id
        http_response&.request_id
      end

      def nouls
        answers_of(NoulAnswer)
      end

      def choices
        answers_of(ChoiceAnswer)
      end

      def scores
        answers_of(ScoreAnswer)
      end

      def to_h
        raw || { "model" => model, "usage" => usage.to_h, "answers" => answers.transform_values(&:to_h) }
      end

      def to_json(*args)
        JSON.generate(to_h, *args)
      end

      private

      def answers_of(klass)
        IndifferentHash.from(answers.select { |_, answer| answer.is_a?(klass) }).freeze
      end
    end
  end
end
