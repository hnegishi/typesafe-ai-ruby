# frozen_string_literal: true

module TypeSafe
  # Hooks for observing requests, in the spirit of stripe-ruby's Instrumentation.
  #
  #   TypeSafe::Instrumentation.subscribe(:request_end) do |event|
  #     StatsD.timing("typesafe.request", event.duration, tags: ["status:#{event.http_status}"])
  #   end
  #
  # :request_begin fires once per client call with a RequestBeginEvent; :request_end fires
  # once per call after any retries with a RequestEndEvent, whether the call succeeded or
  # raised. Anything stored in the begin event's user_data is available on the end event.
  module Instrumentation
    TOPICS = %i[request_begin request_end].freeze

    class RequestBeginEvent
      attr_reader :method, :path, :user_data

      def initialize(method:, path:)
        @method = method
        @path = path
        @user_data = {}
      end
    end

    class RequestEndEvent
      # HTTP method as a Symbol and the request path.
      attr_reader :method, :path
      # Final status code, or nil when no response was received.
      attr_reader :http_status
      # Wall time in seconds for the whole call including retries.
      attr_reader :duration
      # Retries performed after the first attempt.
      attr_reader :num_retries
      # The x-typesafe-request-id of the final response, when present.
      attr_reader :request_id
      # The error raised to the caller, or nil on success.
      attr_reader :error
      # The Hash from the matching RequestBeginEvent.
      attr_reader :user_data

      def initialize(method:, path:, http_status:, duration:, num_retries:, request_id:, error:, user_data:)
        @method = method
        @path = path
        @http_status = http_status
        @duration = duration
        @num_retries = num_retries
        @request_id = request_id
        @error = error
        @user_data = user_data
        freeze
      end
    end

    @subscribers = TOPICS.to_h { |topic| [topic, {}] }
    @mutex = Mutex.new

    class << self
      # Register a block for a topic. Returns the subscription name, which can be
      # passed to unsubscribe. Subscribing again with the same name replaces the block.
      def subscribe(topic, name = Object.new, &block)
        raise ArgumentError, "unknown topic #{topic.inspect}; expected one of #{TOPICS.join(", ")}" unless
          TOPICS.include?(topic)
        raise ArgumentError, "a block is required" unless block

        @mutex.synchronize { @subscribers[topic][name] = block }
        name
      end

      def unsubscribe(topic, name)
        @mutex.synchronize { @subscribers.fetch(topic).delete(name) }
      end

      def notify(topic, event)
        @mutex.synchronize { @subscribers.fetch(topic).values }.each { |block| block.call(event) }
      end

      # Remove every subscriber. Mostly useful in tests.
      def reset!
        @mutex.synchronize { @subscribers.each_value(&:clear) }
      end
    end
  end
end
