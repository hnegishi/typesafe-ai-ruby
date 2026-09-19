# frozen_string_literal: true

require File.expand_path("../test_helper", __dir__)

module TypeSafe
  # Keep the README's Ruby snippets at least syntactically valid.
  class ReadmeTest < Test::Unit::TestCase
    README = File.read(File.expand_path("../../README.md", __dir__))
    SNIPPETS = README.scan(/```ruby\n(.*?)```/m).flatten

    should "contain Ruby snippets" do
      assert_operator SNIPPETS.size, :>=, 5
    end

    SNIPPETS.each_with_index do |snippet, index|
      should "parse snippet #{index + 1}" do
        assert_nothing_raised { RubyVM::InstructionSequence.compile(snippet, "README.md snippet #{index + 1}") }
      end
    end
  end
end
