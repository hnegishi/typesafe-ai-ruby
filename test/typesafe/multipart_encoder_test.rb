# frozen_string_literal: true

require File.expand_path("../test_helper", __dir__)

module TypeSafe
  class MultipartEncoderTest < Test::Unit::TestCase
    should "encode the request part followed by the file parts" do
      encoder = HTTP::MultipartEncoder.new(boundary: "abc123")
      part = HTTP::MultipartEncoder::Part.new(name: "asset-0", content_type: "image/png", content: "\x89PNG\x00".b)
      body = encoder.encode('{"state":"s"}', [part])

      assert_equal "multipart/form-data; boundary=abc123", encoder.content_type
      expected = "--abc123\r\n" \
                 "Content-Disposition: form-data; name=\"request\"\r\n" \
                 "Content-Type: application/json\r\n\r\n" \
                 "{\"state\":\"s\"}\r\n" \
                 "--abc123\r\n" \
                 "Content-Disposition: form-data; name=\"asset-0\"; filename=\"asset-0\"\r\n" \
                 "Content-Type: image/png\r\n\r\n" \
                 "\x89PNG\x00\r\n" \
                 "--abc123--\r\n"
      assert_equal expected.b, body
      assert_equal Encoding::BINARY, body.encoding
    end

    should "use a random boundary by default" do
      assert_not_equal HTTP::MultipartEncoder.new.boundary, HTTP::MultipartEncoder.new.boundary
      assert_match(/\A[0-9a-f]{32}\z/, HTTP::MultipartEncoder.new.boundary)
    end
  end
end
