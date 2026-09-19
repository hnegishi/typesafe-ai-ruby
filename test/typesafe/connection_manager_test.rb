# frozen_string_literal: true

require File.expand_path("../test_helper", __dir__)

module TypeSafe
  class ConnectionManagerTest < Test::Unit::TestCase
    setup do
      @now = 0.0
      @manager = HTTP::ConnectionManager.new(clock: -> { @now })
      @uri = URI(SYSTEM_ONE_URL)
    end

    should "reuse an open connection for the same host" do
      first = @manager.connection_for(@uri, timeout: 10)
      second = @manager.connection_for(URI(MODELS_URL), timeout: 5)
      assert_same first, second
      assert_true first.started?
      assert_true first.use_ssl?
      assert_equal 5, first.read_timeout
      assert_equal 1, @manager.size
    end

    should "open separate connections per scheme, host and port" do
      a = @manager.connection_for(@uri, timeout: 10)
      b = @manager.connection_for(URI("http://localhost:8080/v1/models"), timeout: 10)
      assert_not_same a, b
      assert_false b.use_ssl?
      assert_equal 2, @manager.size
    end

    should "replace connections idle for longer than the idle timeout" do
      first = @manager.connection_for(@uri, timeout: 10)
      @now += HTTP::ConnectionManager::IDLE_TIMEOUT - 1
      assert_same first, @manager.connection_for(@uri, timeout: 10)
      @now += HTTP::ConnectionManager::IDLE_TIMEOUT + 1
      second = @manager.connection_for(@uri, timeout: 10)
      assert_not_same first, second
      assert_false first.started?
    end

    should "drop every connection after a fork" do
      first = @manager.connection_for(@uri, timeout: 10)
      child_pid = Process.pid + 1
      Process.stubs(:pid).returns(child_pid)
      second = @manager.connection_for(@uri, timeout: 10)
      assert_not_same first, second
      assert_false first.started?
    end

    should "discard a connection on request" do
      first = @manager.connection_for(@uri, timeout: 10)
      @manager.discard(@uri)
      assert_false first.started?
      assert_equal 0, @manager.size
      assert_not_same first, @manager.connection_for(@uri, timeout: 10)
    end

    should "clear all connections" do
      first = @manager.connection_for(@uri, timeout: 10)
      @manager.clear
      assert_false first.started?
      assert_equal 0, @manager.size
    end
  end
end
