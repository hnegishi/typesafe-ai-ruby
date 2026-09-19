# frozen_string_literal: true

require File.expand_path("../test_helper", __dir__)

module TypeSafe
  class LoadingTest < Test::Unit::TestCase
    should "define the TypeSafe namespace" do
      assert_true defined?(TypeSafe) ? true : false
    end

    should "have a semantic version" do
      assert_match(/\A\d+\.\d+\.\d+(?:\.[0-9A-Za-z-]+)*\z/, VERSION)
    end
  end
end
