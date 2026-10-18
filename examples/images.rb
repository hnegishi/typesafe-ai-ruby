# frozen_string_literal: true

# Ask questions about a photo (https://docs.typesafe.ai/images). Images are experimental and
# need the :images danger zone. Requires TYPESAFE_API_KEY in the environment.
#
#   ruby -Ilib examples/images.rb door-camera.jpg

require "typesafe-ai-ruby"

path = ARGV.fetch(0, File.expand_path("../test/fixtures/red_square.png", __dir__))
door = TypeSafe::Image.open(path)

client = TypeSafe::Client.new

response = client.system_one(
  state: { door: door },
  questions: {
    person_present: { type: :noul, instructions: "Is there a person in `door`?" },
    carrying: {
      type: :choice,
      instructions: "What is the person in `door` carrying?",
      criteria: { package: "A box or parcel.", bag: "A bag of groceries or shopping.",
                  nothing: "Empty hands or no person." }
    },
    dominant_color: {
      type: :choice,
      instructions: "What is the dominant color of the main object in `door`?",
      criteria: { red: nil, green: nil, blue: nil, other: nil }
    }
  },
  danger_zone: :images
)

puts "model:          #{response.model}  (#{response.usage.input_tokens} input tokens incl. the image)"
puts "person_present: #{response.nouls[:person_present].noul.round(3)}"
carrying = response.choices[:carrying]
puts "carrying:       #{carrying.choice} (confidence #{carrying.confidence.round(2)})"
puts "dominant_color: #{response.choices[:dominant_color].choice}"
