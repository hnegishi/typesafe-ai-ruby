# frozen_string_literal: true

module TypeSafe
  module Responses
    # One model or alias the account can send in the model field.
    class ModelCard
      # The model ID or alias, e.g. "jev-latest".
      attr_reader :name
      # What the model is for.
      attr_reader :description
      # When the model or alias was released.
      attr_reader :release_date
      # The entry as returned by the API.
      attr_reader :raw

      def self.from_hash(hash, path)
        data = Reader.hash!(hash, path)
        new(
          data,
          name: Reader.string!(data["name"], "#{path}.name"),
          description: Reader.optional_string(data["description"], "#{path}.description"),
          release_date: Reader.optional_string(data["release_date"], "#{path}.release_date")
        )
      end

      def initialize(raw, name:, description: nil, release_date: nil)
        @raw = raw.freeze
        @name = name
        @description = description
        @release_date = release_date
        freeze
      end

      def to_h
        raw
      end

      def ==(other)
        other.is_a?(ModelCard) && raw == other.raw
      end
      alias eql? ==

      def hash
        raw.hash
      end
    end

    # The models available to the account.
    class ListModelsResponse
      include Enumerable

      attr_reader :models, :http_response, :raw

      def self.from_http(response)
        json = response.json
        data = Reader.hash!(json, "$")
        new(models: parse_models(data["models"]), http_response: response, raw: data)
      rescue InvalidField => e
        raise Reader.validation_error(e, response, json)
      end

      def self.parse_models(list)
        raise InvalidField.new("models", "expected an array, got #{list.class}") unless list.is_a?(Array)

        list.each_with_index.map { |entry, index| ModelCard.from_hash(entry, "models[#{index}]") }
      end

      def initialize(models:, http_response: nil, raw: nil)
        @models = models.freeze
        @http_response = http_response
        @raw = raw
        freeze
      end

      def each(&)
        models.each(&)
      end

      # Model names.
      def names
        models.map(&:name)
      end

      def request_id
        http_response&.request_id
      end

      def to_h
        raw || { "models" => models.map(&:to_h) }
      end
    end
  end
end
