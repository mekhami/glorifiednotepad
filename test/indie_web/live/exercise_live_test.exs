defmodule IndieWeb.ExerciseLiveTest do
  use IndieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "GET /exercises" do
    test "renders the exercise page", %{conn: conn} do
      {:ok, view, html} = live(conn, "/exercises")

      assert has_element?(view, "#exercise-textarea")
      assert html =~ "No Adjectives or Adverbs"
      assert html =~ "Start writing to see feedback"
    end

    test "displays violations when writing forbidden words", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/exercises")

      view
      |> element("#exercise-textarea")
      |> render_change(%{text: "The beautiful sunset."})

      assert view
             |> element(".panel-violation-count")
             |> render() =~ "1"

      assert view
             |> element(".panel-word")
             |> render() =~ "beautiful"
    end

    test "shows clean state when no violations", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/exercises")

      view
      |> element("#exercise-textarea")
      |> render_change(%{text: "My dog ran across the field and jumped into the lake."})

      assert view
             |> element(".panel-clean")
             |> render() =~ "No forbidden words"
    end

    test "shows word count", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/exercises")

      view
      |> element("#exercise-textarea")
      |> render_change(%{text: "One two three four five."})

      assert view
             |> element(".panel-word-count")
             |> render() =~ "5"
    end
  end
end
