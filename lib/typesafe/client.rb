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

    # Answer named questions about text or structured state.
    def system_one(state:, questions:, model: nil, request_options: {})
      options = RequestOptions.from(request_options)
      body = {
        "state" => Questions::Normalizer.state(state),
        "model" => resolve_model(model),
        "questions" => Questions::Normalizer.questions(questions)
      }
      body.merge!(options.extra_body) if options.extra_body
      response = @requestor.post(Constants::SYSTEM_ONE_PATH, body: body, options: options)
      Responses::SystemOneResponse.from_http(response)
    end

    # The models resource.
    attr_reader :models

    # Release network resources held by the transport.
    def close
      @requestor.close
    end

    private

    def resolve_model(model)
      return config.model if model.nil?
      raise ValidationError, "model must be a non-blank String" if Util.blank?(model)

      model.to_s
    end
  end
end
