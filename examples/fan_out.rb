# frozen_string_literal: true

# Speculative fan-out (https://docs.typesafe.ai/patterns/fan-out).
#
# Jev reads the state once and evaluates every question against it in parallel, so one
# request with many questions is cheaper and faster than many requests with one question.
# Ask everything that might matter and let your code decide what is relevant.
# Requires TYPESAFE_API_KEY in the environment.
#
#   ruby -Ilib examples/fan_out.rb

require "typesafe-ai-ruby"

client = TypeSafe::Client.new

conversation = {
  channel: "chat",
  messages: [
    { role: "customer", text: "I've been charged twice this month and support hasn't replied in 4 days." },
    { role: "agent", text: "I'm sorry about that. Can you share the invoice numbers?" },
    { role: "customer", text: "INV-2231 and INV-2232. If this isn't fixed today I'm cancelling." }
  ]
}

response = client.system_one(
  state: conversation,
  questions: {
    is_billing: TypeSafe.noul("Is this conversation about billing?"),
    is_urgent: TypeSafe.noul("Does the customer need a resolution today?"),
    churn_risk: TypeSafe.noul("Is the customer threatening to leave?"),
    mentions_invoice: TypeSafe.noul("Does the customer cite specific invoice numbers?"),
    tone: TypeSafe.choice("What is the customer's tone in their latest message?",
                          calm: nil, frustrated: nil, angry: nil),
    frustration: TypeSafe.score("How frustrated is the customer overall?",
                                ["Calm", "Mildly annoyed", "Frustrated", "Very angry"]),
    next_action: TypeSafe.choice(
      "What should the agent do next?",
      refund: "Issue a refund for the duplicate charge",
      escalate: "Escalate to a senior agent or manager",
      clarify: "Ask the customer for more information",
      close: "Nothing further is needed"
    )
  }
)

puts "model: #{response.model}  tokens: #{response.usage.input_tokens} in"
response.nouls.each { |name, answer| puts format("  %-17s %.3f", name, answer.noul) }
response.choices.each do |name, answer|
  puts format("  %-17s %s (confidence %.2f)", name, answer.choice, answer.confidence)
end
response.scores.each do |name, answer|
  puts format("  %-17s %.2f -> %s", name, answer.score, answer.legend[answer.score.round])
end

# Decide in code. Only the flags that matter for this workflow are read.
if response.nouls[:churn_risk].noul > 0.8 && response.nouls[:is_billing].noul > 0.8
  puts "\n-> route to retention with a refund offer"
elsif response.choices[:next_action].confidence < 0.6
  puts "\n-> unsure what to do; hand to a human"
else
  puts "\n-> #{response.choices[:next_action].choice}"
end
