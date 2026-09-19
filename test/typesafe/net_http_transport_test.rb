# frozen_string_literal: true

require File.expand_path("../test_helper", __dir__)

module TypeSafe
  class NetHTTPTransportTest < Test::Unit::TestCase
    setup do
      @transport = HTTP::NetHTTPTransport.new
    end

    teardown do
      @transport.close
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

    should "reuse the connection across requests on the same thread" do
      stub_request(:get, MODELS_URL).to_return(body: "{}")
      2.times { @transport.call(build_request(method: :get, url: MODELS_URL, body: nil)) }
      assert_equal 1, @transport.connection_manager.size
      assert_requested :get, MODELS_URL, times: 2
    end

    should "keep one connection manager per thread" do
      stub_request(:get, MODELS_URL).to_return(body: "{}")
      main = @transport.connection_manager
      other = Thread.new { @transport.connection_manager }.value
      assert_not_same main, other
    end

    should "wrap timeouts in APITimeoutError and drop the connection" do
      stub_request(:get, MODELS_URL).to_timeout
      e = assert_raise(APITimeoutError) { @transport.call(build_request(method: :get, url: MODELS_URL, body: nil, timeout: 2)) }
      assert_equal 2, e.timeout
      assert_match(%r{GET https://api.typesafe.ai/v1/models}, e.message)
      assert_equal 0, @transport.connection_manager.size
    end

    should "wrap connection failures in APIConnectionError" do
      stub_request(:get, MODELS_URL).to_raise(Errno::ECONNREFUSED)
      assert_raise(APIConnectionError) { @transport.call(build_request(method: :get, url: MODELS_URL, body: nil)) }

      stub_request(:get, MODELS_URL).to_raise(OpenSSL::SSL::SSLError)
      assert_raise(APIConnectionError) { @transport.call(build_request(method: :get, url: MODELS_URL, body: nil)) }
      assert_equal 0, @transport.connection_manager.size
    end

    should "close every connection" do
      stub_request(:get, MODELS_URL).to_return(body: "{}")
      @transport.call(build_request(method: :get, url: MODELS_URL, body: nil))
      connection = @transport.connection_manager.connection_for(URI(MODELS_URL), timeout: 1)
      @transport.close
      assert_false connection.started?
      assert_equal 0, @transport.connection_manager.size
    end
  end
end
