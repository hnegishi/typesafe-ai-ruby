# frozen_string_literal: true

require File.expand_path("../test_helper", __dir__)

module TypeSafe
  class NetHTTPTransportTest < Test::Unit::TestCase
    setup do
      @transport = HTTP::NetHTTPTransport.new
    end

    should "send the request and wrap the response" do
      stub_request(:post, SYSTEM_ONE_URL)
        .with(body: "{}", headers: { "X-Test" => "1" })
        .to_return(status: 201, body: '{"ok":true}', headers: { "X-TypeSafe-Request-Id" => "req_2" })

      request = build_request(headers: { "X-Test" => "1" }, timeout: 5)
      response = @transport.call(request)
      assert_equal 201, response.status
      assert_equal({ "ok" => true }, response.json)
      assert_equal "req_2", response.request_id
      assert_equal "req_2", response["X-TYPESAFE-REQUEST-ID"]
      assert_same request, response.request
    end

    should "wrap timeouts in APITimeoutError" do
      stub_request(:get, MODELS_URL).to_timeout
      e = assert_raise(APITimeoutError) { @transport.call(build_request(method: :get, url: MODELS_URL, body: nil, timeout: 2)) }
      assert_equal 2, e.timeout
      assert_match(%r{GET https://api.typesafe.ai/v1/models}, e.message)
    end

    should "wrap connection failures in APIConnectionError" do
      stub_request(:get, MODELS_URL).to_raise(Errno::ECONNREFUSED)
      assert_raise(APIConnectionError) { @transport.call(build_request(method: :get, url: MODELS_URL, body: nil)) }

      stub_request(:get, MODELS_URL).to_raise(OpenSSL::SSL::SSLError)
      assert_raise(APIConnectionError) { @transport.call(build_request(method: :get, url: MODELS_URL, body: nil)) }
    end
  end
end
