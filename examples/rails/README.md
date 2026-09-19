# Using typesafe-ai-ruby in Rails

The gem has no Rails specific code; these files show the conventional places to put things.

- `config/initializers/typesafe.rb` configures the default client once and forwards
  instrumentation to `ActiveSupport::Notifications`.
- `app/services/ticket_triage.rb` keeps question definitions as frozen constants and reads
  answers with a confidence gate.
- `app/jobs/triage_ticket_job.rb` layers ActiveJob retries on top of the gem's own retries.
