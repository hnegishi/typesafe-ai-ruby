# frozen_string_literal: true

require File.expand_path("../test_helper", __dir__)

module TypeSafe
  class ClientImagesTest < Test::Unit::TestCase
    BOX_RESPONSE = {
      "model" => "jev-1.14.0",
      "answers" => { "mug" => { "type" => "box", "box" => { "top" => 0.2, "bottom" => 0.8, "left" => 0.1, "right" => 0.9 },
                                "confidence" => 0.9 },
                     "person" => { "type" => "noul", "noul" => 0.7 } },
      "usage" => { "input_tokens" => 300, "output_tokens" => 20 }
    }.freeze

    def multipart_json(request)
      request.body[%r{name="request"\r\nContent-Type: application/json\r\n\r\n(.*?)\r\n--}m, 1]
    end

    should "send images placed in the request as multipart assets" do
      door = png_image
      stub_request(:post, SYSTEM_ONE_URL).to_return(json_response(BOX_RESPONSE))

      response = build_client.system_one(
        state: { door: door },
        questions: { person: { type: :noul, instructions: "Is there a person in `door`?" },
                     mug: TypeSafe.box("the mug in `door`") },
        model: "jev-preview", danger_zone: :images
      )

      assert_in_delta 0.2, response.boxes[:mug].box.top
      assert_requested(:post, SYSTEM_ONE_URL) do |req|
        json = JSON.parse(multipart_json(req))
        req.headers["Content-Type"].start_with?("multipart/form-data; boundary=") &&
          req.headers["Typesafe-Danger-Zone-Images"] == "true" &&
          json["state"] == { "door" => door.reference } &&
          json["assets"] == { door.reference => { "type" => "image", "part" => "asset-0" } } &&
          json["model"] == "jev-preview" &&
          req.body.include?("name=\"asset-0\"; filename=\"asset-0\"\r\nContent-Type: image/png\r\n\r\n#{PNG_BYTES}")
      end
    end

    should "send attached images written into text and named assets" do
      door = png_image
      poster = png_image
      stub_request(:post, SYSTEM_ONE_URL).to_return(json_response(BOX_RESPONSE))

      build_client(danger_zone: [:images]).system_one(
        state: { photo: door },
        questions: { same: TypeSafe.noul("Is the dog in `photo` the dog in #{poster}? See also badge-ref.") },
        assets: { poster.reference => poster, "badge-ref" => png_image }
      )

      assert_requested(:post, SYSTEM_ONE_URL) do |req|
        json = JSON.parse(multipart_json(req))
        json["assets"].keys == [door.reference, poster.reference, "badge-ref"] &&
          json["assets"]["badge-ref"] == { "type" => "image", "part" => "asset-2" } &&
          req.body.scan("Content-Type: image/png").size == 3
      end
    end

    should "send JSON when no images are involved even with the danger zone on" do
      stub_request(:post, SYSTEM_ONE_URL).to_return(json_response(system_one_response_fixture))
      build_client.system_one(state: "x", questions: { q: TypeSafe.noul("y") }, danger_zone: :images)
      assert_requested(:post, SYSTEM_ONE_URL, headers: { "Content-Type" => "application/json" })
    end

    should "refuse images and box questions unless the danger zone is on" do
      client = build_client
      e = assert_raise(ValidationError) { client.system_one(state: png_image, questions: { q: TypeSafe.noul("y") }) }
      assert_match(/danger_zone: :images/, e.message)
      assert_raise(ValidationError) { client.system_one(state: "x", questions: { q: TypeSafe.box("the mug") }) }
      assert_not_requested :post, SYSTEM_ONE_URL
    end

    should "accept the raw header as opting in" do
      stub_request(:post, SYSTEM_ONE_URL).to_return(json_response(BOX_RESPONSE))
      build_client.system_one(state: png_image, questions: { q: TypeSafe.noul("y") },
                              request_options: { headers: { "typesafe-danger-zone-images" => "true" } })
      assert_requested :post, SYSTEM_ONE_URL
    end

    should "reject unattached references, unused assets and images in extra_body" do
      client = build_client(danger_zone: :images)
      stray = png_image
      assert_raise(ValidationError) { client.system_one(state: "see #{stray}", questions: { q: TypeSafe.noul("y") }) }
      assert_raise(ValidationError) { client.system_one(state: "x", questions: { q: TypeSafe.noul("y") }, assets: [stray]) }
      assert_raise(ValidationError) do
        client.system_one(state: "x", questions: { q: TypeSafe.noul("y") }, request_options: { extra_body: { pic: stray } })
      end
      assert_not_requested :post, SYSTEM_ONE_URL
    end
  end
end
