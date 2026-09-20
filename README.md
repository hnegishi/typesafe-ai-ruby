# TypeSafe AI Ruby Library

[![CI](https://github.com/hnegishi/typesafe-ai-ruby/actions/workflows/ci.yml/badge.svg)](https://github.com/hnegishi/typesafe-ai-ruby/actions/workflows/ci.yml)

The TypeSafe AI Ruby library provides convenient access to the [TypeSafe](https://typesafe.ai) System One API from applications written in Ruby. Send state and typed questions to Jev, and get back structured answers with probabilities and confidence that your code can use directly.

See the [TypeSafe documentation](https://docs.typesafe.ai/) for the concepts behind the API.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "typesafe-ai-ruby"
```

Or install it yourself:

```sh
gem install typesafe-ai-ruby
```

### Requirements

- Ruby 3.1 or newer.
- No runtime dependencies beyond the Ruby standard library.

## Usage

Get an API key from the [TypeSafe console](https://console.typesafe.ai/keys) and export it as `TYPESAFE_API_KEY`:

```sh
export TYPESAFE_API_KEY=...
```

The client reads it automatically, so `TypeSafe::Client.new` needs no arguments. You can also pass `api_key:` explicitly.

```ruby
require "typesafe-ai-ruby"

client = TypeSafe::Client.new

response = client.system_one(
  state: "I was charged twice. Please fix this ASAP.",
  questions: {
    department: {
      type: :choice,
      instructions: "Which team should handle this?",
      criteria: { billing: "Payment issues", technical: "Bugs or integrations", sales: "Pricing questions" }
    },
    frustration: {
      type: :score,
      instructions: "How frustrated is the customer?",
      criteria: ["Calm", "Frustrated but civil", "Very angry"]
    },
    is_urgent: { type: :noul, instructions: "Does the message convey urgency?" }
  }
)

response.choices[:department].choice      # => "billing"
response.choices[:department].confidence  # => 1.0
response.scores[:frustration].score       # => 1.06
response.nouls[:is_urgent].noul           # => 0.97
response.model                            # => "jev-1.13.0"
```

### Questions

Questions are plain Hashes matching the [API reference](https://docs.typesafe.ai/api): a `type`, optional `instructions`, and type-specific `criteria`. Instructions and descriptions can be a string, a Hash, or an Array.

- `noul` asks a yes/no question and returns the probability of yes. Criteria are optional: `criteria: { true: "Spam", false: "A real conversation" }`.
- `choice` picks one option from a set. Criteria are required; use `nil` when the name speaks for itself.
- `score` rates the state against ordered levels. Criteria are an Array of at least two levels, and each level's index is its score.

Extra keys are passed through untouched, so new API fields work before this library knows about them.

To reuse a question, keep a `TypeSafe::Noul`, `TypeSafe::Choice` or `TypeSafe::Score` in a constant and pass it in place of a Hash:

```ruby
DEPARTMENT = TypeSafe::Choice.new(instructions: "Which team should handle this?",
                                  criteria: { billing: nil, technical: nil, sales: nil })

client.system_one(state: ticket, questions: { department: DEPARTMENT })
```

`state` is whatever the questions are about: a String, a Hash, or an Array. Symbols are converted to strings, and objects that respond to `as_json` are converted through it.

### Answers

`system_one` returns a `TypeSafe::Responses::SystemOneResponse`. Answers are keyed by question name and accept String or Symbol keys.

```ruby
response.answers          # every answer
response.nouls            # only Noul answers
response.choices          # only Choice answers, with #choice, #probabilities and #confidence
response.scores           # only Score answers, with #score, #legend, #probabilities and #confidence
response.usage.input_tokens
response.request_id
response.to_h             # the raw JSON body
```

Use `confidence` to decide whether to act on an answer automatically or hand it to a human. See `examples/` for confidence-gated routing and asking many questions in one request.

### Errors

Errors inherit from `TypeSafe::Error`. HTTP failures raise a subclass of `TypeSafe::APIError` with `status`, `body`, `headers`, `endpoint` and `request_id`.

```ruby
begin
  client.system_one(state: ticket, questions: questions)
rescue TypeSafe::RateLimitError => e
  sleep(e.retry_after || 1)
rescue TypeSafe::APIError => e
  logger.error("TypeSafe #{e.status}: #{e.message} (request #{e.request_id})")
rescue TypeSafe::APIConnectionError => e
  # no HTTP response; includes TypeSafe::APITimeoutError
end
```

Malformed questions raise `TypeSafe::ValidationError` before anything is sent.

## Configuration

Options can be passed to `TypeSafe::Client.new` or set once for the default client. Explicit options win over environment variables, which win over the defaults.

```ruby
TypeSafe.configure do |c|
  c.api_key = ENV.fetch("TYPESAFE_API_KEY")
  c.model = "jev-1.13.0"                       # TYPESAFE_DEFAULT_MODEL, default jev-latest
  c.base_url = "https://api.typesafe.ai"       # TYPESAFE_BASE_URL
  c.timeout = 10                               # seconds per attempt
  c.logger = Logger.new($stdout)
  c.log_level = :info                          # TYPESAFE_LOG_LEVEL, default :warn
end

TypeSafe.client.system_one(state: "...", questions: { urgent: { type: :noul, instructions: "Is this urgent?" } })
```

Per-call overrides go in `request_options`:

```ruby
client.system_one(state: "...", questions: questions, model: "jev-preview",
                  request_options: { timeout: 30, headers: { "X-Team" => "growth" } })
```

### Retries

Requests that fail with 408, 429, 5xx, a connection error or a timeout are retried twice with exponential backoff, honoring `Retry-After`. Adjust or disable this with a `retry_policy`:

```ruby
client = TypeSafe::Client.new(retry_policy: { max_retries: 5, backoff_max: 10 })
client.models.list(request_options: { retry_policy: { max_retries: 0 } })
```

### Logging and instrumentation

At `:info` the client logs one line per request and each retry. At `:debug` it also logs headers and bodies, with credential headers redacted.

`TypeSafe::Instrumentation` reports every call once it finishes, including retries:

```ruby
TypeSafe::Instrumentation.subscribe(:request_end) do |event|
  StatsD.timing("typesafe.request", event.duration, tags: ["status:#{event.http_status}"])
end
```

### Rails

The library has no Rails specific code. Configure the default client in an initializer, keep question definitions in frozen constants, and layer ActiveJob retries on top of the built-in ones. `examples/rails/` shows each of these.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then run `bundle exec rake` to run the tests, RuboCop and the RBS validation.

The live API tests are skipped unless `TYPESAFE_API_KEY` is set:

```sh
TYPESAFE_API_KEY=... bundle exec rake test:integration
```

To release a new version, update the version number in `lib/typesafe/version.rb` and the changelog, then push a matching `v*` tag. The release workflow publishes the gem to RubyGems through trusted publishing.

## License

The gem is available as open source under the terms of the [MIT License](LICENSE.txt).
