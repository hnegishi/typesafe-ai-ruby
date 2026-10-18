# frozen_string_literal: true

require File.expand_path("../test_helper", __dir__)

module TypeSafe
  class ImageTest < Test::Unit::TestCase
    PNG = "\x89PNG\r\n\x1a\n#{"\x00" * 32}".b.freeze
    JPEG = "\xFF\xD8\xFF\xE0#{"\x00" * 32}".b.freeze

    should "build from bytes and detect the format" do
      png = Image.new(PNG)
      assert_equal "image/png", png.content_type
      assert_equal "png", png.format
      assert_equal PNG.bytesize, png.bytesize
      assert_equal "image/jpeg", Image.new(JPEG).content_type
      assert_true png.bytes.frozen?
      assert_equal Encoding::BINARY, png.bytes.encoding
    end

    should "build from a file read on first use" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "photo.jpg")
        File.binwrite(path, JPEG)
        image = Image.open(path)
        assert_equal path, image.path
        assert_equal "image/jpeg", image.content_type
        assert_equal JPEG, image.bytes
      end
      missing = Image.open("/nonexistent/photo.jpg")
      assert_raise(ValidationError) { missing.bytes }
    end

    should "build from base64 text ignoring whitespace" do
      text = [PNG].pack("m0")
      wrapped = text.scan(/.{1,10}/).join("\n")
      assert_equal PNG, Image.from_base64(wrapped).bytes
      assert_raise(ValidationError) { Image.from_base64("not base64!") }
      assert_raise(ValidationError) { Image.from_base64(nil) }
    end

    should "reject empty, oversized and non-image data" do
      assert_raise(ValidationError) { Image.new("") }
      assert_raise(ValidationError) { Image.new(123) }
      assert_raise(ArgumentError) { Image.new(nil) }
      assert_raise(ArgumentError) { Image.new(PNG, path: "x") }
      assert_raise(ValidationError) { Image.new("GIF89a....").content_type }
      assert_nothing_raised { Image.new(PNG).validate! }
      assert_raise(ValidationError) { Image.new("\x00" * (Image::MAX_BYTES + 1)) }
    end

    should "have a unique reference used by to_s and to_json" do
      a = Image.new(PNG)
      b = Image.new(PNG)
      assert_match(/\A<image:[0-9a-f]{32}>\z/, a.reference)
      assert_not_equal a.reference, b.reference
      assert_equal a.reference, a.to_s
      assert_equal a.reference.to_json, a.to_json
      assert_equal "Compare #{a.reference} with the listing.", "Compare #{a} with the listing."
      assert_true Image.reference?(a.reference)
      assert_false Image.reference?("see #{a.reference}")
      assert_false Image.reference?("<image:xyz>")
      assert_match(/#<TypeSafe::Image \d+ bytes <image:/, a.inspect)
    end
  end
end
