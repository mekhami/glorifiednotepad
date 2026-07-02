defmodule Indie.WritingExercises.Lexicon do
  @moduledoc """
  Lexicon of English adjectives and adverbs, compiled from the
  Grady Ward Moby Part-of-Speech II data set (public domain).

  Loaded at compile time from `priv/mobypos.txt`. The file maps words
  to POS codes:
    A = adjective, v = adverb, N = noun, V = verb, etc.

  Words whose codes contain 'A' or 'v' are extracted into separate sets
  for O(1) lookup.
  """

  @lexicon_path Path.expand("../../../priv/mobypos.txt", __DIR__)
  @external_resource @lexicon_path

  {adj_set, adv_set} =
    @lexicon_path
    |> File.stream!([:raw, :read], :line)
    |> Stream.map(&String.trim/1)
    |> Stream.reject(&(&1 == "" or not String.valid?(&1) or String.contains?(&1, " ")))
    |> Enum.reduce({MapSet.new(), MapSet.new()}, fn line, {adj, adv} ->
      case String.split(line, "\\", parts: 2) do
        [word, pos] ->
          word = String.downcase(word)

          adj =
            if String.contains?(pos, "A"), do: MapSet.put(adj, word), else: adj

          adv =
            if String.contains?(pos, "v"), do: MapSet.put(adv, word), else: adv

          {adj, adv}

        _ ->
          {adj, adv}
      end
    end)

  @adjective_set adj_set
  @adverb_set adv_set

  @doc """
  Returns `true` if the word is in the adjective lexicon.
  """
  @spec adjective?(String.t()) :: boolean()
  def adjective?(word) when is_binary(word) do
    MapSet.member?(@adjective_set, String.downcase(word))
  end

  @doc """
  Returns `true` if the word is in the adverb lexicon.
  """
  @spec adverb?(String.t()) :: boolean()
  def adverb?(word) when is_binary(word) do
    MapSet.member?(@adverb_set, String.downcase(word))
  end

  @doc """
  Returns the number of unique adjectives in the lexicon.
  """
  @spec adjective_count() :: non_neg_integer()
  def adjective_count, do: MapSet.size(@adjective_set)

  @doc """
  Returns the number of unique adverbs in the lexicon.
  """
  @spec adverb_count() :: non_neg_integer()
  def adverb_count, do: MapSet.size(@adverb_set)
end
