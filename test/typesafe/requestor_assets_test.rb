# frozen_string_literal: true

require File.expand_path("../test_helper", __dir__)

module TypeSafe
  class RequestorAssetsTest < Test::Unit::TestCase
    OK = { status: 200, headers: {}, body: "{}" }.freeze
    PNG = "\x89PNG\r\n\x1a\n#{"\x00" * 8}".b.freeze

    def build_requestor(transport, **options)
      config = Configuration.new(api_key: "k", logger: Logger.new(File::NULL), **options).resolve(env: {})
      HTTP::Requestor.new(config, transport: transport, sleeper: ->(_) {})
    end

    should "send a multipart body with the assets map and one part per image" do
      transport = FakeTransport.new(OK)
      image = Image.new(PNG)
      build_requestor(transport).post("/v1/systemone", body: { "state" => image.reference },
                                                       assets: { image.reference => image })
      request = transport.requests.first
      boundary = request.headers["Content-Type"][/boundary=(\h+)/, 1]
      assert_match(%r{\Amultipart/form-data; boundary=\h{32}\z}, request.headers["Content-Type"])
      assert_includes request.body, "--#{boundary}\r\nContent-Disposition: form-data; name=\"request\"\r\n"
      json = request.body[%r{name="request"\r\nContent-Type: application/json\r\n\r\n(.*?)\r\n--}m, 1]
      assert_equal({ "state" => image.reference,
                     "assets" => { image.reference => { "type" => "image", "part" => "asset-0" } } }, JSON.parse(json))
      assert_includes request.body, "name=\"asset-0\"; filename=\"asset-0\"\r\nContent-Type: image/png\r\n\r\n#{PNG}\r\n"
      assert_true request.body.end_with?("--#{boundary}--\r\n")
    end

    should "number parts in asset order" do
      transport = FakeTransport.new(OK)
      a = Image.new(PNG)
      b = Image.new("\xFF\xD8\xFF\xE0#{"\x00" * 8}".b)
      build_requestor(transport).post("/v1/systemone", body: {}, assets: { "first" => a, "second" => b })
      body = transport.requests.first.body
      assert_includes body, '"assets":{"first":{"type":"image","part":"asset-0"},"second":{"type":"image","part":"asset-1"}}'
      assert_includes body, "name=\"asset-1\"; filename=\"asset-1\"\r\nContent-Type: image/jpeg\r\n"
    end

    should "resend the same multipart body on retry" do
      transport = FakeTransport.new({ status: 503, headers: {}, body: "" }, OK)
      image = Image.new(PNG)
      build_requestor(transport).post("/v1/systemone", body: {}, assets: { image.reference => image })
      assert_equal 2, transport.requests.size
      assert_equal transport.requests[0].body, transport.requests[1].body
      assert_equal transport.requests[0].headers["Content-Type"], transport.requests[1].headers["Content-Type"]
    end

    should "summarize file parts in debug logs instead of dumping them" do
      io = StringIO.new
      image = Image.new(PNG)
      build_requestor(FakeTransport.new(OK), logger: Logger.new(io), log_level: :debug)
        .post("/v1/systemone", body: { "state" => image.reference }, assets: { image.reference => image })
      assert_match(%r{asset-0 \(image/png, #{PNG.bytesize} bytes\)}, io.string)
      assert_not_includes io.string, PNG
    end
  end
end
