# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "typesafe-ai-ruby"
require "test/unit"
require "mocha/test_unit"
require "shoulda/context"
require "stringio"
require "webmock/test_unit"

require File.expand_path("test_data", __dir__)

# Disable all real network connections. Tests stub HTTP with WebMock or a FakeTransport.
WebMock.disable_net_connect!

module Test
  module Unit
    class TestCase
      include TypeSafe::TestData
    end
  end
end
