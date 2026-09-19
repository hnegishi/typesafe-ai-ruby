# frozen_string_literal: true

# Confidence-gated routing (https://docs.typesafe.ai/patterns/confidence-routing).
#
# The answer tells you what; confidence tells you whether to act on it automatically.
# Requires TYPESAFE_API_KEY in the environment.
#
#   ruby -Ilib examples/confidence_routing.rb

require "typesafe-ai-ruby"

AUTO_THRESHOLD = 0.7

client = TypeSafe::Client.new

tickets = [
  "My invoice shows two charges for the same month. Please refund one.",
  "The webhook endpoint returns 500 since your deploy this morning.",
  "Hi, just wondering what your plans cost and whether there's an annual discount?",
  "Something is wrong with my account, can you look into it?"
]

tickets.each do |ticket|
  response = client.system_one(
    state: ticket,
    questions: {
      department: TypeSafe.choice(
        "Which team should handle this?",
        billing: "Payments, invoicing, refunds",
        technical: "Bugs, outages, integrations",
        sales: "Pricing, upgrades, new accounts"
      )
    }
  )

  answer = response.choices[:department]
  route = answer.confidence >= AUTO_THRESHOLD ? answer.choice : "human review"
  puts format("%-10s (%.2f) <- %s", route, answer.confidence, ticket)
end
