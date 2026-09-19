# frozen_string_literal: true

require "json"
require "logger"
require "net/http"
require "openssl"
require "uri"

require_relative "typesafe/version"
require_relative "typesafe/constants"
require_relative "typesafe/util"
require_relative "typesafe/errors"

# Ruby client for the TypeSafe AI System One API.
#
# See https://docs.typesafe.ai/ for the HTTP API this gem wraps.
module TypeSafe
end
