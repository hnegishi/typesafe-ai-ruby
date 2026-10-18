# frozen_string_literal: true

require File.expand_path("../test_helper", __dir__)

module TypeSafe
  class AssetsTest < Test::Unit::TestCase
    context ".attach" do
      should "accept nil, an image, an array or a named hash" do
        image = png_image
        assert_equal({}, Assets.attach(nil))
        assert_equal({ image.reference => image }, Assets.attach(image))
        assert_equal({ image.reference => image }, Assets.attach([image]))
        assert_equal({ "poster" => image }, Assets.attach({ poster: image }))
      end

      should "reject other values" do
        assert_raise(ValidationError) { Assets.attach("x") }
        assert_raise(ValidationError) { Assets.attach(["x"]) }
        assert_raise(ValidationError) { Assets.attach({ "a" => "x" }) }
        assert_raise(ValidationError) { Assets.attach({ " " => png_image }) }
        assert_raise(ValidationError) { Assets.attach({ "x" * 1025 => png_image }) }
      end
    end

    context ".resolve" do
      should "merge collected and attached images" do
        a = png_image
        b = png_image
        json = JSON.generate("state" => a.reference, "q" => "see poster")
        assert_equal({ a.reference => a, "poster" => b }, Assets.resolve([a], { "poster" => b }, json))
      end

      should "reject references to images that are not attached" do
        a = png_image
        e = assert_raise(ValidationError) { Assets.resolve([], {}, JSON.generate("state" => "look at #{a}")) }
        assert_match(/not attached/, e.message)
        assert_nothing_raised { Assets.resolve([], { a.reference => a }, JSON.generate("state" => "look at #{a}")) }
      end

      should "reject attached images that are never referenced" do
        a = png_image
        e = assert_raise(ValidationError) { Assets.resolve([], { "poster" => a }, JSON.generate("state" => "x")) }
        assert_match(/not referenced/, e.message)
      end

      should "match references as they appear inside JSON" do
        a = png_image
        json = JSON.generate("state" => 'see "quoted" ref')
        assert_nothing_raised { Assets.resolve([], { '"quoted"' => a }, json) }
      end

      should "validate the image bytes" do
        bad = Image.new("GIF89a....")
        assert_raise(ValidationError) { Assets.resolve([bad], {}, JSON.generate("state" => bad.reference)) }
      end
    end
  end
end
