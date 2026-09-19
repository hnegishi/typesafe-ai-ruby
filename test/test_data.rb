# frozen_string_literal: true

module TypeSafe
  # Shared fixtures and helpers mixed into every test case.
  module TestData
    API_KEY = "sk_test_123"
    API_BASE = "https://api.typesafe.ai"
    SYSTEM_ONE_URL = "#{API_BASE}/v1/systemone".freeze
    MODELS_URL = "#{API_BASE}/v1/models".freeze

    def fixture(name)
      File.read(File.expand_path("fixtures/#{name}", __dir__))
    end

    def fixture_json(name)
      JSON.parse(fixture(name))
    end

    def system_one_response_fixture
      fixture("system_one_response.json")
    end

    def list_models_response_fixture
      fixture("list_models_response.json")
    end

    def build_client(**options)
      TypeSafe::Client.new(api_key: API_KEY, logger: Logger.new(File::NULL), **options)
    end

    def json_response(body, status: 200, headers: {})
      body = JSON.generate(body) unless body.is_a?(String)
      { status: status, body: body, headers: { "Content-Type" => "application/json" }.merge(headers) }
    end

    def build_request(method: :post, url: SYSTEM_ONE_URL, headers: {}, body: "{}", timeout: 10)
      TypeSafe::HTTP::Request.new(method: method, uri: URI(url), headers: headers, body: body, timeout: timeout)
    end

    def build_response(status, body, headers = {}, request: build_request)
      TypeSafe::HTTP::Response.new(status: status, headers: headers, body: body, request: request)
    end

    # A transport that records requests and returns canned responses in order.
    # Pass a Hash of status/headers/body per call, or an exception to raise.
    class FakeTransport
      attr_reader :requests

      def initialize(*responses)
        @responses = responses
        @requests = []
      end

      def call(request)
        @requests << request
        response = @responses.shift
        raise response if response.is_a?(Exception)

        TypeSafe::HTTP::Response.new(**response, request: request)
      end

      def close; end
    end
  end
end
