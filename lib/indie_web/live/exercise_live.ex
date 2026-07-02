defmodule IndieWeb.ExerciseLive do
  use IndieWeb, :live_view

  alias Indie.WritingExercises.Exercise
  alias Indie.WritingExercises.Checker

  def mount(_params, _session, socket) do
    exercise = Exercise.exercise(:no_adj_adv)
    result = Checker.check("", exercise.check_rules)

    socket =
      socket
      |> assign(:exercise, exercise)
      |> assign(:text, "")
      |> assign(:violations, result.violations)
      |> assign(:word_count, result.word_count)
      |> assign(:page_title, "Writing Exercise")

    {:ok, socket}
  end

  def handle_event("check", %{"text" => text}, socket) do
    exercise = socket.assigns.exercise
    result = Checker.check(text, exercise.check_rules)

    socket =
      socket
      |> assign(:text, text)
      |> assign(:violations, result.violations)
      |> assign(:word_count, result.word_count)

    {:noreply, socket}
  end

  defp tag_label(:adj), do: "adjective"
  defp tag_label(:adv), do: "adverb"
  defp tag_label(_), do: ""

  defp progress_pct(count, exercise) do
    cond do
      count >= exercise.min_words -> 100
      true -> trunc(count / exercise.min_words * 100)
    end
  end

  defp progress_color(count, exercise) do
    cond do
      count >= exercise.min_words and count <= exercise.max_words -> "fill-green"
      count > exercise.max_words -> "fill-red"
      true -> "fill-yellow"
    end
  end
end
