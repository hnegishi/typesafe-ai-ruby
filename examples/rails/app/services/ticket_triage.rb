# frozen_string_literal: true

# app/services/ticket_triage.rb
#
# Questions are frozen value objects, so they can live in constants and be reused across
# requests. State can be a Hash; ActiveModel objects work too through as_json.
class TicketTriage
  AUTO_ROUTE_CONFIDENCE = 0.7

  QUESTIONS = {
    department: TypeSafe.choice(
      "Which team should handle this?",
      billing: "Payments, invoicing, refunds",
      technical: "Bugs, outages, integrations",
      sales: "Pricing, upgrades, new accounts"
    ),
    frustration: TypeSafe.score("How frustrated is the customer?", ["Calm", "Frustrated", "Very angry"]),
    is_urgent: TypeSafe.noul("Does the message convey urgency?")
  }.freeze

  def self.call(ticket)
    response = TypeSafe.client.system_one(
      state: { subject: ticket.subject, body: ticket.body },
      questions: QUESTIONS
    )

    department = response.choices[:department]
    ticket.update!(
      department: department.confidence >= AUTO_ROUTE_CONFIDENCE ? department.choice : "needs_review",
      frustration: response.scores[:frustration].score,
      urgent: response.nouls[:is_urgent].noul > 0.8,
      triage_model: response.model
    )
  end
end
