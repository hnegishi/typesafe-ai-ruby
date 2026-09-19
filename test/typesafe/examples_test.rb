# frozen_string_literal: true

require File.expand_path("../test_helper", __dir__)

module TypeSafe
  # The examples need a real API key (or Rails) to run, so only check that they parse.
  class ExamplesTest < Test::Unit::TestCase
    EXAMPLES = Dir[File.expand_path("../../examples/**/*.rb", __dir__)]

    should "find the examples" do
      assert_true EXAMPLES.size >= 4
    end

    EXAMPLES.each do |path|
      should "parse #{path.sub(%r{.*/examples/}, "")}" do
        assert_nothing_raised { RubyVM::InstructionSequence.compile(File.read(path), path) }
      end
    end
  end
end
