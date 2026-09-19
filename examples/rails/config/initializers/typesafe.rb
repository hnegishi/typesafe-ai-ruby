# frozen_string_literal: true

# config/initializers/typesafe.rb

TypeSafe.configure do |c|
  c.api_key = Rails.application.credentials.dig(:typesafe, :api_key) # falls back to TYPESAFE_API_KEY
  c.model = "jev-1.13.0" # pin a version in production; aliases move when new releases ship
  c.timeout = 10
  c.logger = Rails.logger
  c.log_level = Rails.env.production? ? :warn : :info
end

# Forward request events to ActiveSupport::Notifications so they show up in your
# existing APM, lograge or StatsD subscribers.
TypeSafe::Instrumentation.subscribe(:request_end) do |event|
  ActiveSupport::Notifications.instrument(
    "request.typesafe",
    method: event.method, path: event.path, status: event.http_status, duration: event.duration,
    retries: event.num_retries, request_id: event.request_id, error: event.error&.class&.name
  )
end
