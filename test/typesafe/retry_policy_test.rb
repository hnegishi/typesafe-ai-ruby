# frozen_string_literal: true

require File.expand_path("../test_helper", __dir__)

module TypeSafe
  class RetryPolicyTest < Test::Unit::TestCase
    class FixedRandom
      def initialize(value)
        @value = value
      end

      def rand
        @value
      end
    end

    context "defaults" do
      should "match the official SDKs" do
        policy = RetryPolicy.new
        assert_equal 2, policy.max_retries
        assert_in_delta 0.5, policy.backoff_initial
        assert_in_delta 5.0, policy.backoff_max
        assert_in_delta 0.25, policy.backoff_jitter
        assert_equal [408, 429] + (500..599).to_a, policy.http_statuses
        assert_true policy.respect_retry_after
        assert_in_delta 60.0, policy.max_retry_after
        assert_true policy.api_connection_error
        assert_true policy.api_timeout_error
        assert_in_delta 30.0, policy.timeout
        assert_true policy.frozen?
        assert_equal RetryPolicy::DEFAULT, policy
      end
    end

    context ".from" do
      should "accept nil, a policy or a hash of overrides" do
        assert_same RetryPolicy::DEFAULT, RetryPolicy.from(nil)
        policy = RetryPolicy.new(max_retries: 5)
        assert_same policy, RetryPolicy.from(policy)
        assert_equal 0, RetryPolicy.from({ "max_retries" => 0 }).max_retries
        assert_equal RetryPolicy.new(max_retries: 5, timeout: nil), RetryPolicy.from({ timeout: nil }, base: policy)
        assert_raise(ArgumentError) { RetryPolicy.from(3) }
      end
    end

    context "#with" do
      should "return a modified copy" do
        base = RetryPolicy.new
        modified = base.with(max_retries: 0, http_statuses: [503])
        assert_equal 0, modified.max_retries
        assert_equal [503], modified.http_statuses
        assert_equal 2, base.max_retries
      end
    end

    should "validate its fields" do
      assert_raise(ArgumentError) { RetryPolicy.new(max_retries: -1) }
      assert_raise(ArgumentError) { RetryPolicy.new(max_retries: 1.5) }
      assert_raise(ArgumentError) { RetryPolicy.new(backoff_initial: -1) }
      assert_raise(ArgumentError) { RetryPolicy.new(backoff_jitter: 2) }
      assert_raise(ArgumentError) { RetryPolicy.new(timeout: "10") }
    end

    context "#retry_status? and #retry_error?" do
      should "follow the configured statuses and flags" do
        policy = RetryPolicy.new
        assert_true policy.retry_status?(429)
        assert_true policy.retry_status?(529)
        assert_false policy.retry_status?(422)
        assert_true policy.retry_error?(APIConnectionError.new("x"))
        assert_true policy.retry_error?(APITimeoutError.new(timeout: 1))
        assert_false policy.retry_error?(ValidationError.new("x"))

        strict = policy.with(api_connection_error: false, api_timeout_error: false)
        assert_false strict.retry_error?(APIConnectionError.new("x"))
        assert_false strict.retry_error?(APITimeoutError.new(timeout: 1))
      end
    end

    context "#delay_for" do
      should "double the backoff up to the maximum" do
        policy = RetryPolicy.new(backoff_initial: 0.5, backoff_max: 5.0, backoff_jitter: 0.25)
        random = FixedRandom.new(0)
        assert_in_delta 0.5, policy.delay_for(0, random: random)
        assert_in_delta 1.0, policy.delay_for(1, random: random)
        assert_in_delta 2.0, policy.delay_for(2, random: random)
        assert_in_delta 4.0, policy.delay_for(3, random: random)
        assert_in_delta 5.0, policy.delay_for(4, random: random)
        assert_in_delta 5.0, policy.delay_for(10, random: random)
      end

      should "subtract up to the jitter fraction" do
        policy = RetryPolicy.new(backoff_initial: 1.0, backoff_jitter: 0.25)
        assert_in_delta 0.75, policy.delay_for(0, random: FixedRandom.new(1))
        assert_in_delta 0.875, policy.delay_for(0, random: FixedRandom.new(0.5))
        20.times { assert_includes 0.75..1.0, policy.delay_for(0) }
      end

      should "honor Retry-After within max_retry_after" do
        policy = RetryPolicy.new(max_retry_after: 10)
        assert_in_delta 3.0, policy.delay_for(0, headers: { "retry-after" => "3" })
        assert_in_delta 0.25, policy.delay_for(0, headers: { "retry-after-ms" => "250", "retry-after" => "3" })
        assert_in_delta 0.5, policy.delay_for(0, headers: { "retry-after" => "11" }, random: FixedRandom.new(0))
        assert_in_delta 0.5, policy.delay_for(0, headers: {}, random: FixedRandom.new(0))
      end

      should "ignore Retry-After when disabled" do
        policy = RetryPolicy.new(respect_retry_after: false)
        assert_in_delta 0.5, policy.delay_for(0, headers: { "retry-after" => "3" }, random: FixedRandom.new(0))
      end
    end
  end
end
