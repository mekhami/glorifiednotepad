defmodule Indie.WritingExercises.TaggerTest do
  use ExUnit.Case, async: true

  alias Indie.WritingExercises.Tagger

  describe "tag/1" do
    test "tags known adjectives" do
      assert Tagger.tag("beautiful") == :adj
      assert Tagger.tag("quick") == :adj
      assert Tagger.tag("loud") == :adj
      assert Tagger.tag("shallow") == :adj
    end

    test "tags known adverbs" do
      assert Tagger.tag("quickly") == :adv
      assert Tagger.tag("very") == :adv
      assert Tagger.tag("well") == :adv
    end

    test "tags function words" do
      assert Tagger.tag("the") == :det
      assert Tagger.tag("run") == :vb
      assert Tagger.tag("cat") == :nn
      assert Tagger.tag("in") == :prep
      assert Tagger.tag("and") == :conj
      assert Tagger.tag("she") == :pron
    end

    test "uses suffix rules for unknown adjectives" do
      assert Tagger.tag("wonderful") == :adj
      assert Tagger.tag("dangerous") == :adj
      assert Tagger.tag("expressive") == :adj
      assert Tagger.tag("comfortable") == :adj
      assert Tagger.tag("careless") == :adj
      assert Tagger.tag("athletic") == :adj
      assert Tagger.tag("natural") == :adj
    end

    test "uses suffix rule for -ly adverbs" do
      assert Tagger.tag("softly") == :adv
      assert Tagger.tag("silently") == :adv
      assert Tagger.tag("carefully") == :adv
    end

    test "lexicon takes precedence over suffix rules" do
      # "lovely" ends in -ly but is an adjective in lexicon
      assert Tagger.tag("lovely") == :adj
      assert Tagger.tag("friendly") == :adj
      # "butterfly" ends in -ly but is a noun
      assert Tagger.tag("butterfly") == :nn
    end

    test "falls back to noun for unknown words" do
      assert Tagger.tag("xyzzynotaword") == :nn
    end

    test "is case insensitive" do
      assert Tagger.tag("Beautiful") == :adj
      assert Tagger.tag("BEAUTIFUL") == :adj
    end
  end

  describe "tag_words/1" do
    test "tags a list of words" do
      result = Tagger.tag_words(["the", "quick", "brown", "fox"])
      assert result == [
        %{word: "the", tag: :det},
        %{word: "quick", tag: :adj},
        %{word: "brown", tag: :adj},
        %{word: "fox", tag: :nn}
      ]
    end

    test "preserves original word casing in output" do
      result = Tagger.tag_words(["The", "Quick"])
      assert result == [
        %{word: "The", tag: :det},
        %{word: "Quick", tag: :adj}
      ]
    end
  end
end
