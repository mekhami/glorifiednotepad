defmodule Indie.WritingExercises.Checker do
  @moduledoc """
  Runs the POS tagger over text and filters results for forbidden word types.
  """

  alias Indie.WritingExercises.Tagger

  @doc """
  Checks text against a list of rules.

  Returns `%{violations: [%{word: String.t(), tag: atom()}], word_count: non_neg_integer()}`.
  """
  def check(text, rules) when is_binary(text) and is_list(rules) do
    words = tokenize(text)
    tagged = Tagger.tag_words(words)

    forbidden_tags =
      rules
      |> Enum.flat_map(fn
        :no_adjectives -> [:adj]
        :no_adverbs -> [:adv]
        _ -> []
      end)
      |> MapSet.new()

    violations = Enum.filter(tagged, fn %{tag: tag} -> tag in forbidden_tags end)

    %{
      violations: violations,
      word_count: length(words)
    }
  end

  defp tokenize(text) do
    text
    |> String.split(~r/[\s]+/, trim: true)
    |> Enum.map(fn token ->
      token
      |> String.replace(~r/^[^\w'‘’]+/u, "")
      |> String.replace(~r/[^\w'‘’]+$/u, "")
    end)
    |> Enum.reject(&(&1 == ""))
  end
end
