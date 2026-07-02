defmodule Indie.WritingExercises.CheckerTest do
  use ExUnit.Case, async: true

  alias Indie.WritingExercises.Checker

  describe "check/2" do
    test "returns violations for adjectives" do
      result = Checker.check("The beautiful sunset.", [:no_adjectives])
      assert length(result.violations) == 1
      assert hd(result.violations).word == "beautiful"
      assert hd(result.violations).tag == :adj
    end

    test "returns violations for adverbs" do
      result = Checker.check("She walked quickly.", [:no_adverbs])
      assert length(result.violations) == 1
      assert hd(result.violations).word == "quickly"
      assert hd(result.violations).tag == :adv
    end

    test "returns violations for both rules combined" do
      result = Checker.check("The beautiful sky glowed brightly.", [:no_adjectives, :no_adverbs])
      assert length(result.violations) == 2
      tags = Enum.map(result.violations, & &1.tag)
      assert :adj in tags
      assert :adv in tags
    end

    test "returns empty list for clean text" do
      result = Checker.check("The sun set over the hill.", [:no_adjectives, :no_adverbs])
      assert result.violations == []
    end

    test "returns word count" do
      result = Checker.check("One two three four five.", [:no_adjectives])
      assert result.word_count == 5
    end

    test "handles empty text" do
      result = Checker.check("", [:no_adjectives, :no_adverbs])
      assert result.violations == []
      assert result.word_count == 0
    end

    test "handles punctuation" do
      result = Checker.check("The quick, brown fox -- yes!", [:no_adjectives, :no_adverbs])
      words = Enum.map(result.violations, & &1.word)
      assert "quick" in words
      assert "brown" in words
    end

    test "no rules returns empty violations" do
      result = Checker.check("The beautiful sunset.", [])
      assert result.violations == []
    end
  end
end
