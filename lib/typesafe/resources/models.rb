# frozen_string_literal: true

module TypeSafe
  module Resources
    # Access to the models available to the account, reached through Client#models.
    class Models
      def initialize(requestor)
        @requestor = requestor
      end

      # List the models and aliases the account can send in the model field.
      def list(request_options: {})
        response = @requestor.get(Constants::MODELS_PATH, options: RequestOptions.from(request_options))
        Responses::ListModelsResponse.from_http(response)
      end
    end
  end
end
