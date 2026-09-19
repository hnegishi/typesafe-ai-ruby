# frozen_string_literal: true

require File.expand_path("../test_helper", __dir__)

module TypeSafe
  class RetrierTest < Test::Unit::TestCase
    class FakeClock
      attr_accessor :now

      def initialize
        @now = 0.0
      end

      def call
        @now
      end
    end

    setup do
      @sleeps = []
      @clock = FakeClock.new
      @random = Object.new.tap { |o| o.define_singleton_method(:rand) { 0 } }
    end

    def retrier(policy = RetryPolicy.new, on_retry: nil)
      HTTP::Retrier.new(policy, sleeper: ->(s) { @sleeps << s }, clock: @clock, random: @random, on_retry: on_retry)
    end

    def status_error(status, headers = {})
      APIError.from_response(build_response(status, "", headers))
    end

    should "return the block's value on success" do
      assert_equal(:ok, retrier.run { :ok })
      assert_empty @sleeps
    end

    should "retry retryable errors with backoff and pass the attempt number" do
      attempts = []
      result = retrier.run do |attempt|
        attempts << attempt
        raise status_error(503) if attempt < 2

        :ok
      end
      assert_equal :ok, result
      assert_equal [0, 1, 2], attempts
      assert_equal [0.5, 1.0], @sleeps
    end

    should "re-raise after max_retries" do
      e = assert_raise(InternalServerError) { retrier.run { raise status_error(503) } }
      assert_equal 503, e.status
      assert_equal 2, @sleeps.size
    end

    should "not retry non-retryable statuses or errors" do
      assert_raise(UnprocessableEntityError) { retrier.run { raise status_error(422) } }
      assert_raise(ValidationError) { retrier.run { raise ValidationError, "x" } }
      policy = RetryPolicy.new(api_timeout_error: false)
      assert_raise(APITimeoutError) { retrier(policy).run { raise APITimeoutError.new(timeout: 1) } }
      assert_empty @sleeps
    end

    should "retry connection errors and timeouts" do
      calls = 0
      retrier.run do
        calls += 1
        raise APIConnectionError, "reset" if calls == 1
        raise APITimeoutError.new(timeout: 1) if calls == 2
      end
      assert_equal 3, calls
      assert_equal 2, @sleeps.size
    end

    should "use Retry-After from the failed response" do
      retrier.run { |attempt| raise status_error(429, { "retry-after-ms" => "1500" }) if attempt.zero? }
      assert_equal [1.5], @sleeps
    end

    should "disable retries with max_retries 0" do
      assert_raise(RateLimitError) { retrier(RetryPolicy.new(max_retries: 0)).run { raise status_error(429) } }
      assert_empty @sleeps
    end

    should "stop when the next delay would exceed the total budget" do
      policy = RetryPolicy.new(max_retries: 5, timeout: 2.0)
      calls = 0
      e = assert_raise(OverloadedError) do
        retrier(policy).run do
          calls += 1
          @clock.now += 0.8
          raise status_error(529)
        end
      end
      assert_equal 529, e.status
      assert_equal 2, calls
      assert_equal [0.5], @sleeps
    end

    should "report each retry to on_retry" do
      reported = []
      retrier(on_retry: ->(error, attempt, delay) { reported << [error.class, attempt, delay] })
        .run { |attempt| raise status_error(503) if attempt.zero? }
      assert_equal [[InternalServerError, 0, 0.5]], reported
    end
  end
end
