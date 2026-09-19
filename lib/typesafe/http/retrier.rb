# frozen_string_literal: true

module TypeSafe
  module HTTP
    # Runs a block until it succeeds or the RetryPolicy gives up. The block receives the
    # attempt number (0 for the first try) and raises APIError or APIConnectionError on failure.
    # The last error is re-raised when no more retries are allowed or the total budget
    # would be exceeded by the next delay.
    class Retrier
      MONOTONIC = Process::CLOCK_MONOTONIC

      attr_reader :policy

      def initialize(policy, sleeper: nil, clock: nil, random: Kernel, on_retry: nil)
        @policy = policy
        @sleeper = sleeper || Kernel.method(:sleep)
        @clock = clock || -> { Process.clock_gettime(MONOTONIC) }
        @random = random
        @on_retry = on_retry
      end

      def run
        started = @clock.call
        attempt = 0
        loop do
          return yield(attempt)
        rescue APIError, APIConnectionError => e
          delay = retry_delay(e, attempt, started)
          raise if delay.nil?

          @on_retry&.call(e, attempt, delay)
          @sleeper.call(delay)
          attempt += 1
        end
      end

      private

      def retry_delay(error, attempt, started)
        return nil unless attempt < policy.max_retries && retryable?(error)

        delay = policy.delay_for(attempt, headers: error.respond_to?(:headers) ? error.headers : nil, random: @random)
        return nil if policy.timeout && (@clock.call - started + delay) >= policy.timeout

        delay
      end

      def retryable?(error)
        case error
        when APIError then policy.retry_status?(error.status)
        when APIConnectionError then policy.retry_error?(error)
        else false
        end
      end
    end
  end
end
