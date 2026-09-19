# frozen_string_literal: true

# app/jobs/triage_ticket_job.rb
#
# The gem already retries 429, 5xx, connection failures and timeouts a couple of times with
# short backoff. ActiveJob handles the longer outages, and request errors are discarded
# because resending the same body cannot succeed.
class TriageTicketJob < ApplicationJob
  queue_as :default

  retry_on TypeSafe::RateLimitError, wait: :polynomially_longer, attempts: 5
  retry_on TypeSafe::InternalServerError, TypeSafe::APIConnectionError, wait: 30.seconds, attempts: 3
  discard_on TypeSafe::UnprocessableEntityError, TypeSafe::ValidationError

  def perform(ticket_id)
    TicketTriage.call(Ticket.find(ticket_id))
  end
end
