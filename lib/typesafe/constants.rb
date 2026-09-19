# frozen_string_literal: true

module TypeSafe
  # Environment variable names, client defaults, endpoint paths, and header names.
  #
  # Values mirror the official TypeSafe Python and JavaScript SDKs so that
  # configuration behaves the same across languages.
  module Constants
    # Environment variable holding the API key.
    API_KEY_ENV = "TYPESAFE_API_KEY"
    # Environment variable overriding the API base URL.
    BASE_URL_ENV = "TYPESAFE_BASE_URL"
    # Environment variable overriding the default model.
    DEFAULT_MODEL_ENV = "TYPESAFE_DEFAULT_MODEL"
    # Environment variable overriding the log level.
    LOG_LEVEL_ENV = "TYPESAFE_LOG_LEVEL"

    # Default API base URL.
    DEFAULT_BASE_URL = "https://api.typesafe.ai"
    # Default model alias.
    DEFAULT_MODEL = "jev-latest"
    # Default timeout in seconds for each HTTP attempt.
    DEFAULT_TIMEOUT = 10.0
    # Default log level.
    DEFAULT_LOG_LEVEL = :warn

    # Path of the System One evaluation endpoint.
    SYSTEM_ONE_PATH = "/v1/systemone"
    # Path of the model listing endpoint.
    MODELS_PATH = "/v1/models"

    # Identifier sent in User-Agent and X-TypeSafe-SDK headers.
    SDK_NAME = "typesafe-ruby"
    # MIME type used for request and response bodies.
    JSON_CONTENT_TYPE = "application/json"

    # HTTP header names used by the client.
    module Headers
      AUTHORIZATION = "Authorization"
      ACCEPT = "Accept"
      CONTENT_TYPE = "Content-Type"
      USER_AGENT = "User-Agent"
      SDK = "X-TypeSafe-SDK"
      RUNTIME = "X-TypeSafe-Runtime"
      RETRY_COUNT = "X-TypeSafe-Retry-Count"
      REQUEST_ID = "x-typesafe-request-id"
    end
  end
end
