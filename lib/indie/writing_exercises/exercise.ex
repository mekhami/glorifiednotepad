defmodule Indie.WritingExercises.Exercise do
  @moduledoc """
  Defines a writing exercise with rules and constraints.
  """

  defstruct [:id, :title, :instructions, :min_words, :max_words, :check_rules]

  @doc "Look up an exercise by its atom id."
  def exercise(id) do
    Enum.find_value(exercises(), fn e ->
      if e.id == id, do: e
    end) || raise KeyError, key: id, term: __MODULE__
  end

  @doc "List all registered exercises."
  def list_exercises, do: exercises()

  defp exercises do
    [
      %__MODULE__{
        id: :no_adj_adv,
        title: "No Adjectives or Adverbs",
        instructions:
          "Write a paragraph (200–350 words) of descriptive narrative prose " <>
            "without adjectives or adverbs. No dialogue. The point is to give a " <>
            "vivid description of a scene or an action using only verbs, nouns, " <>
            "pronouns, and articles. Adverbs of time (then, next, later, etc.) " <>
            "may be necessary, but be sparing. Be chaste.",
        min_words: 200,
        max_words: 350,
        check_rules: [:no_adjectives, :no_adverbs]
      }
    ]
  end
end
