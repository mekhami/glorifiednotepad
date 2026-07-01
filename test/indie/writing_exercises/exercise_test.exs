defmodule Indie.WritingExercises.ExerciseTest do
  use ExUnit.Case, async: true

  alias Indie.WritingExercises.Exercise

  describe "Exercise struct" do
    test "builds a valid exercise" do
      exercise = %Exercise{
        id: :no_adj_adv,
        title: "No Adjectives or Adverbs",
        instructions: "Write a paragraph...",
        min_words: 200,
        max_words: 350,
        check_rules: [:no_adjectives, :no_adverbs]
      }

      assert exercise.id == :no_adj_adv
      assert exercise.min_words == 200
    end

    test "exercise/1 returns the registered exercise" do
      exercise = Exercise.exercise(:no_adj_adv)
      assert exercise.id == :no_adj_adv
      assert exercise.title == "No Adjectives or Adverbs"
    end

    test "exercise/1 raises on unknown id" do
      assert_raise KeyError, fn ->
        Exercise.exercise(:bogus)
      end
    end

    test "list_exercises/0 returns all exercises" do
      exercises = Exercise.list_exercises()
      assert length(exercises) > 0
      assert Enum.all?(exercises, &match?(%Exercise{}, &1))
    end
  end
end
