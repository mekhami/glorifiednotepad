defmodule Indie.WritingExercises.LexiconTest do
  use ExUnit.Case, async: true

  alias Indie.WritingExercises.Lexicon

  describe "adjective?/1" do
    test "returns true for known adjectives" do
      assert Lexicon.adjective?("beautiful")
      assert Lexicon.adjective?("quick")
      assert Lexicon.adjective?("stubborn")
      assert Lexicon.adjective?("unassuming")
    end

    test "returns false for non-adjectives" do
      refute Lexicon.adjective?("run")
      refute Lexicon.adjective?("the")
      refute Lexicon.adjective?("and")
      refute Lexicon.adjective?("eager")
    end

    test "is case insensitive" do
      assert Lexicon.adjective?("Beautiful")
      assert Lexicon.adjective?("BEAUTIFUL")
    end
  end

  describe "adverb?/1" do
    test "returns true for known adverbs" do
      assert Lexicon.adverb?("quickly")
      assert Lexicon.adverb?("silently")
      assert Lexicon.adverb?("very")
    end

    test "returns false for non-adverbs" do
      refute Lexicon.adverb?("run")
      refute Lexicon.adverb?("cat")
    end
  end

  describe "counts" do
    test "has a substantial number of adjectives" do
      assert Lexicon.adjective_count() > 40_000
    end

    test "has a substantial number of adverbs" do
      assert Lexicon.adverb_count() > 10_000
    end
  end
end
