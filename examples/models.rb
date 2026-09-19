# frozen_string_literal: true

# List the models and aliases the account can use, then pin a request to a specific version.
# Requires TYPESAFE_API_KEY in the environment.
#
#   ruby -Ilib examples/models.rb

require "typesafe-ai-ruby"

client = TypeSafe::Client.new

models = client.models.list
models.each { |model| puts format("%-12s %-12s %s", model.name, model.release_date, model.description) }

# Aliases such as jev-latest move when a new release ships. If you tuned confidence
# thresholds against one version, send its versioned ID and upgrade on your own schedule.
response = client.system_one(
  state: "Ship it today or we lose the deal.",
  questions: { urgent: TypeSafe.noul("Is this urgent?") },
  model: models.names.first
)
puts "\nanswered by #{response.model}: urgent=#{response.nouls[:urgent].noul.round(3)}"
