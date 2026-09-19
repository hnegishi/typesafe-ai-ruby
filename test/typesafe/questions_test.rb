# frozen_string_literal: true

require File.expand_path("../test_helper", __dir__)

module TypeSafe
  class QuestionsTest < Test::Unit::TestCase
    context "Noul" do
      should "serialize to the wire format" do
        q = Noul.new(instructions: "Spam?", criteria: { true: "ad", false: nil })
        assert_equal({ "type" => "noul", "instructions" => "Spam?", "criteria" => { "true" => "ad", "false" => nil } },
                     q.to_h)
        assert_equal({ "type" => "noul" }, Noul.new.to_h)
        assert_equal({ "type" => "noul", "criteria" => { "true" => "yes" } }, Noul.new(criteria: { "true" => "yes" }).to_h)
      end

      should "reject criteria keys other than true and false" do
        assert_raise(ValidationError) { Noul.new(criteria: { maybe: "x" }) }
        assert_raise(ValidationError) { Noul.new(criteria: %w[a b]) }
      end
    end

    context "Choice" do
      should "serialize to the wire format" do
        q = Choice.new(instructions: "Tone?", criteria: { calm: nil, angry: { "signals" => [:shouting] } })
        assert_equal({ "type" => "choice", "instructions" => "Tone?",
                       "criteria" => { "calm" => nil, "angry" => { "signals" => ["shouting"] } } }, q.to_h)
      end

      should "require a non-empty Hash of options" do
        assert_raise(ValidationError) { Choice.new(criteria: {}) }
        assert_raise(ValidationError) { Choice.new(criteria: %w[a b]) }
        assert_raise(ValidationError) { Choice.new(criteria: { "" => nil }) }
        assert_raise(ArgumentError) { Choice.new(instructions: "x") }
      end
    end

    context "Score" do
      should "serialize to the wire format" do
        q = Score.new(instructions: "Urgency?", criteria: ["can wait", :today])
        assert_equal({ "type" => "score", "instructions" => "Urgency?", "criteria" => ["can wait", "today"] }, q.to_h)
      end

      should "require at least two levels" do
        assert_raise(ValidationError) { Score.new(criteria: ["only one"]) }
        assert_raise(ValidationError) { Score.new(criteria: { a: 1, b: 2 }) }
        assert_raise(ValidationError) { Score.new(criteria: ["a", nil]) }
      end
    end

    should "accept structured instructions" do
      q = Noul.new(instructions: { question: "Is it spam?", context: [:email] })
      assert_equal({ "question" => "Is it spam?", "context" => ["email"] }, q.instructions)
    end

    should "be frozen value objects" do
      a = Score.new(criteria: %w[x y])
      b = Score.new(criteria: %w[x y])
      assert_true a.frozen?
      assert_equal a, b
      assert_equal a.hash, b.hash
      assert_equal '{"type":"score","criteria":["x","y"]}', a.to_json
    end

    context "module helpers" do
      should "build questions from positional or keyword criteria" do
        assert_equal Noul.new(instructions: "Spam?", criteria: { true: "ad" }), TypeSafe.noul("Spam?", true: "ad")
        assert_equal Noul.new(instructions: "Spam?", criteria: { "false" => "chat" }),
                     TypeSafe.noul("Spam?", { "false" => "chat" })
        assert_equal Choice.new(instructions: "Tone?", criteria: { calm: nil, angry: nil }),
                     TypeSafe.choice("Tone?", calm: nil, angry: nil)
        assert_equal Score.new(instructions: "U?", criteria: %w[a b]), TypeSafe.score("U?", %w[a b])
      end

      should "reject mixing positional and keyword criteria" do
        assert_raise(ArgumentError) { TypeSafe.choice("x", { a: nil }, b: nil) }
        assert_raise(ValidationError) { TypeSafe.choice("x") }
      end
    end
  end

  class NormalizerTest < Test::Unit::TestCase
    context ".state" do
      should "accept strings, hashes and arrays" do
        assert_equal "text", Questions::Normalizer.state("text")
        assert_equal({ "message" => "hi", "tags" => ["a"] }, Questions::Normalizer.state({ message: "hi", tags: [:a] }))
        assert_equal([1, "two"], Questions::Normalizer.state([1, :two]))
      end

      should "reject nil and scalars" do
        assert_raise(ValidationError) { Questions::Normalizer.state(nil) }
        assert_raise(ValidationError) { Questions::Normalizer.state(42) }
        assert_raise(ValidationError) { Questions::Normalizer.state(Object.new) }
      end
    end

    context ".questions" do
      should "accept question objects and raw hashes together" do
        wire = Questions::Normalizer.questions(
          billing: Noul.new(instructions: "Billing?"),
          "tone" => { type: "choice", instructions: "Tone?", criteria: { calm: nil, angry: nil }, weight: 2 }
        )
        assert_equal(
          {
            "billing" => { "type" => "noul", "instructions" => "Billing?" },
            "tone" => { "type" => "choice", "instructions" => "Tone?",
                        "criteria" => { "calm" => nil, "angry" => nil }, "weight" => 2 }
          }, wire
        )
      end

      should "validate before anything is sent" do
        assert_raise(ValidationError) { Questions::Normalizer.questions({}) }
        assert_raise(ValidationError) { Questions::Normalizer.questions(nil) }
        assert_raise(ValidationError) { Questions::Normalizer.questions("" => Noul.new) }
        assert_raise(ValidationError) { Questions::Normalizer.questions(q: "noul") }
        assert_raise(ValidationError) { Questions::Normalizer.questions(q: { instructions: "no type" }) }
        assert_raise(ValidationError) { Questions::Normalizer.questions(q: { type: "score", criteria: ["one"] }) }
        assert_raise(ValidationError) { Questions::Normalizer.questions(q: { type: "choice" }) }
        assert_raise(ValidationError) { Questions::Normalizer.questions(q: { type: "noul", criteria: { maybe: 1 } }) }
      end

      should "pass unknown question types through untouched" do
        wire = Questions::Normalizer.questions(q: { type: "rank", items: %w[a b] })
        assert_equal({ "q" => { "type" => "rank", "items" => %w[a b] } }, wire)
      end
    end
  end
end
