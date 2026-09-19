# frozen_string_literal: true

require "test_helper"

class LoadingTest < Minitest::Test
  def test_gem_entry_point_defines_namespace
    assert defined?(TypeSafe), "TypeSafe module should be defined"
  end

  def test_version_follows_semver
    assert_match(/\A\d+\.\d+\.\d+(?:\.[0-9A-Za-z-]+)*\z/, TypeSafe::VERSION)
  end
end
