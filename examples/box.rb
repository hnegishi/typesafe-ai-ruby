# frozen_string_literal: true

# Find where something is in an image with a Box question (https://docs.typesafe.ai/primitives/box).
# Box questions need Jev 1.14 (jev-preview) and the :images danger zone.
# Requires TYPESAFE_API_KEY in the environment.
#
#   ruby -Ilib examples/box.rb photo.jpg "the coffee mug"

require "typesafe-ai-ruby"

path = ARGV.fetch(0, File.expand_path("../test/fixtures/red_square.png", __dir__))
target = ARGV.fetch(1, "the red square")
photo = TypeSafe::Image.open(path)

client = TypeSafe::Client.new

response = client.system_one(
  state: { photo: photo },
  questions: {
    # A Box always returns a box, so ask a Noul alongside it to learn whether the target is there at all.
    present: TypeSafe.noul("Is #{target} visible in `photo`?"),
    location: TypeSafe.box("#{target} in `photo`")
  },
  model: "jev-preview",
  danger_zone: :images
)

answer = response.boxes[:location]
puts "model:      #{response.model}"
puts "present:    #{response.nouls[:present].noul.round(3)}"
puts "box:        top=#{answer.box.top.round(3)} bottom=#{answer.box.bottom.round(3)} " \
     "left=#{answer.box.left.round(3)} right=#{answer.box.right.round(3)}"
puts "confidence: #{answer.confidence&.round(3) || "n/a"}"

# Multiply the edges by the image size to get a pixel crop box, in [left, top, right, bottom] order.
width = height = 280 # the bundled fixture; read your image's real size with your image library
puts "pixels:     #{answer.box.to_pixels(width: width, height: height).inspect}"
