# frozen_string_literal: true

module TypeSafe
  # Client for the TypeSafe AI API.
  #
  # Explicit options take precedence over environment variables, then SDK defaults.
  # Instances are immutable and safe to share between threads.
  #
  # For example:
  #   client = TypeSafe::Client.new(api_key: "sk-...")
  #   response = client.system_one(
  #     state: "I was charged twice. Please help.",
  #     questions: { billing: TypeSafe::Noul.new(instructions: "Is this about billing?") }
  #   )
  #   response.nouls[:billing].noul # => 0.98
  class Client
    # The resolved, frozen configuration.
    attr_reader :config

    def initialize(**options)
      @config = Configuration.new(**options).resolve
      @requestor = HTTP::Requestor.new(@config)
      @models = Resources::Models.new(@requestor)
    end

    # Answer named questions about text, structured state, or images.
    #
    # Images placed in state or questions are sent as assets automatically. Images written into
    # text through their reference go in assets:, as an Array or as a Hash of your own
    # reference names. Images and box questions need the :images danger zone turned on.
    #
    # danger_zone turns on experimental features for this call, such as :images; it is a
    # shortcut for request_options: { danger_zone: [...] }.
    def system_one(state:, questions:, model: nil, assets: nil, danger_zone: nil, request_options: {})
      options = RequestOptions.from(request_options, danger_zone: danger_zone)
      collected = []
      body = {
        "state" => Questions::Normalizer.state(state, assets: collected),
        "model" => resolve_model(model),
        "questions" => Questions::Normalizer.questions(questions, assets: collected)
      }
      body.merge!(options.extra_body) if options.extra_body
      asset_map = Assets.resolve(collected, Assets.attach(assets), JSON.generate(body))
      ensure_images_enabled!(asset_map, body["questions"], options)
      response = @requestor.post(Constants::SYSTEM_ONE_PATH, body: body, options: options, assets: asset_map)
      Responses::SystemOneResponse.from_http(response)
    end

    # The models resource.
    attr_reader :models

    # Release network resources held by the transport.
    def close
      @requestor.close
    end

    private

    def ensure_images_enabled!(assets, questions, options)
      return if assets.empty? && questions.none? { |_, question| question["type"] == Questions::Box::TYPE }
      return if images_enabled?(options)

      raise ValidationError,
            "images and box questions are experimental; turn them on with danger_zone: :images"
    end

    def images_enabled?(options)
      return true if (config.danger_zone + options.danger_zone).include?(:images)

      header = Constants::Headers::DANGER_ZONE_IMAGES.downcase
      [config.headers, options.headers].any? do |headers|
        headers.any? { |name, value| name.downcase == header && value.to_s.casecmp?("true") }
      end
    end

    def resolve_model(model)
      return config.model if model.nil?
      raise ValidationError, "model must be a non-blank String" if Util.blank?(model)

      model.to_s
    end
  end
end
