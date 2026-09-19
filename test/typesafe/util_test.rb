# frozen_string_literal: true

require File.expand_path("../test_helper", __dir__)

module TypeSafe
  class UtilTest < Test::Unit::TestCase
    context ".blank?" do
      should "be true for nil and whitespace" do
        assert_true Util.blank?(nil)
        assert_true Util.blank?("  ")
        assert_false Util.blank?("x")
      end
    end

    context ".env_value" do
      should "ignore blank values and strip whitespace" do
        env = { "A" => "  ", "B" => " v " }
        assert_nil Util.env_value(env, "A")
        assert_equal "v", Util.env_value(env, "B")
        assert_nil Util.env_value(env, "C")
      end
    end

    context ".deep_stringify" do
      should "convert symbols and keys while keeping scalars" do
        input = { a: :sym, "b" => [1, 2.5, true, nil, { c: "d" }], 1 => "one" }
        assert_equal({ "a" => "sym", "b" => [1, 2.5, true, nil, { "c" => "d" }], "1" => "one" },
                     Util.deep_stringify(input))
      end

      should "convert objects through as_json" do
        obj = Object.new
        def obj.as_json(*)
          { "id" => 1, tags: [:x] }
        end
        assert_equal({ "id" => 1, "tags" => ["x"] }, Util.deep_stringify(obj))
      end

      should "reject unknown objects, non-finite floats and bad keys" do
        assert_raise(ValidationError) { Util.deep_stringify(Object.new) }
        assert_raise(ValidationError) { Util.deep_stringify(Float::NAN) }
        assert_raise(ValidationError) { Util.deep_stringify({ x: Float::INFINITY }) }
        assert_raise(ValidationError) { Util.deep_stringify({ Object.new => 1 }) }
      end
    end

    context ".parse_retry_after" do
      should "prefer retry-after-ms over Retry-After" do
        assert_in_delta 1.5, Util.parse_retry_after("retry-after-ms" => "1500", "retry-after" => "9")
      end

      should "parse Retry-After in seconds" do
        assert_in_delta 9.0, Util.parse_retry_after("Retry-After" => "9")
      end

      should "parse Retry-After as an HTTP date" do
        assert_in_delta 30.0, Util.parse_retry_after("retry-after" => (Time.now + 30).httpdate), 2.0
        assert_in_delta 0.0, Util.parse_retry_after("retry-after" => (Time.now - 30).httpdate)
      end

      should "return nil when absent or unparseable" do
        assert_nil Util.parse_retry_after("retry-after" => "soon")
        assert_nil Util.parse_retry_after({})
      end
    end

    context ".summarize_body" do
      should "pick a human readable message out of common error shapes" do
        assert_equal "boom", Util.summarize_body({ "error" => "boom" })
        assert_equal "boom", Util.summarize_body({ "error" => { "message" => "boom" } })
        assert_equal "nope", Util.summarize_body({ "message" => "nope" })
        assert_equal '[{"loc":["body","state"]}]', Util.summarize_body({ "detail" => [{ "loc" => %w[body state] }] })
        assert_equal "plain", Util.summarize_body(" plain ")
        assert_equal "", Util.summarize_body(nil)
      end

      should "truncate long bodies" do
        assert_equal "#{"x" * 10}...", Util.summarize_body("x" * 20, limit: 10)
      end
    end
  end

  class IndifferentHashTest < Test::Unit::TestCase
    should "look up string keys with symbols" do
      hash = IndifferentHash.from(foo: 1)
      assert_equal 1, hash[:foo]
      assert_equal 1, hash["foo"]
      assert_equal 1, hash.fetch(:foo)
      assert_true hash.key?(:foo)
      assert_equal({ "foo" => 1 }, hash)
    end
  end
end
