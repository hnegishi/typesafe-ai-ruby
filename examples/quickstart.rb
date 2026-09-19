# frozen_string_literal: true

# Mirrors https://docs.typesafe.ai/introduction/quickstart. Requires TYPESAFE_API_KEY in the environment.
#
#   ruby -Ilib examples/quickstart.rb

require "typesafe-ai-ruby"

client = TypeSafe::Client.new

ticket = "Hi, I've been trying to connect my Stripe account for 3 days and it keeps failing. " \
         "I'm losing sales. Please help ASAP."

response = client.system_one(
  state: ticket,
  questions: {
    department: TypeSafe::Choice.new(
      instructions: "Which team should handle this",
      criteria: {
        billing: "Payment or subscription issues",
        technical: "Bugs or integration problems",
        sales: "Pricing or account questions"
      }
    ),
    frustration: TypeSafe::Score.new(
      instructions: "How frustrated the customer appears",
      criteria: ["Calm, just stating facts", "Frustrated but civil", "Very angry, strong language"]
    ),
    is_urgent: TypeSafe::Noul.new(instructions: "The message conveys urgency or time-sensitivity")
  }
)

puts "model:       #{response.model}"
puts "request_id:  #{response.request_id}"
puts "department:  #{response.choices[:department].choice} " \
     "(confidence #{response.choices[:department].confidence.round(3)})"
puts "frustration: #{response.scores[:frustration].score.round(3)} " \
     "-> #{response.scores[:frustration].legend[response.scores[:frustration].score.round]}"
puts "is_urgent:   #{response.nouls[:is_urgent].noul.round(3)}"
puts "usage:       #{response.usage.input_tokens} in / #{response.usage.output_tokens} out"

puts "\nmodels:"
client.models.list.each { |m| puts "  #{m.name}  #{m.release_date}  #{m.description}" }
