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

Get an API key from the [TypeSafe console](https://console.typesafe.ai/settings/keys) and set it as `TYPESAFE_API_KEY`, or pass it to the client.

```ruby
require "typesafe-ai-ruby"

client = TypeSafe::Client.new(api_key: ENV["TYPESAFE_API_KEY"])

response = client.system_one(
  state: "I've been trying to connect my Stripe account for 3 days and it keeps failing. Please help ASAP.",
  questions: {
    department: TypeSafe.choice("Which team should handle this?", billing: nil, technical: nil, sales: nil),
    frustration: TypeSafe.score("How frustrated is the customer?", ["Calm", "Frustrated", "Very angry"]),
    is_urgent: TypeSafe.noul("Does the message convey urgency?")
  }
)

response.choices[:department].choice      # => "billing"
response.choices[:department].confidence  # => 0.45
response.scores[:frustration].score       # => 1.0
response.nouls[:is_urgent].noul           # => 0.99
```

There are three question types. `TypeSafe.noul` asks a yes/no question and returns the probability of yes. `TypeSafe.choice` picks one option and returns the choice with a probability per option and a confidence. `TypeSafe.score` rates the state against ordered levels and returns the expected score, a legend, probabilities and a confidence. Use the confidence to decide whether to act on an answer or hand it to a human.

`state` can be a String, a Hash or an Array. Answers come back under the names you chose, with String or Symbol keys, and `response.to_h` gives you the raw JSON.

HTTP failures raise a subclass of `TypeSafe::APIError`, such as `TypeSafe::RateLimitError`, with `status`, `body` and `request_id`. Network failures raise `TypeSafe::APIConnectionError`. Malformed questions raise `TypeSafe::ValidationError` before anything is sent.

## Configuration

Options can be passed to `TypeSafe::Client.new` or set once for the default client. Explicit options win over environment variables, which win over the defaults.

```ruby
TypeSafe.configure do |c|
  c.api_key = ENV.fetch("TYPESAFE_API_KEY")   # TYPESAFE_API_KEY
  c.model = "jev-1.13.0"                       # TYPESAFE_DEFAULT_MODEL, default jev-latest
  c.base_url = "https://api.typesafe.ai"       # TYPESAFE_BASE_URL
  c.timeout = 10                               # seconds per attempt
  c.logger = Logger.new($stdout)
  c.log_level = :info                          # TYPESAFE_LOG_LEVEL, default :warn
end

TypeSafe.client.system_one(state: "...", questions: { urgent: TypeSafe.noul("Is this urgent?") })
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

## License

The gem is available as open source under the terms of the [MIT License](LICENSE.txt).
