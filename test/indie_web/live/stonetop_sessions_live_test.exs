defmodule IndieWeb.StonetopSessionsLiveTest do
  use IndieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  alias Indie.Stonetop

  test "shows an empty state with no sessions", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/stonetop/sessions")
    assert has_element?(view, "#sessions-empty")
  end

  test "opens the latest session and navigates between them", %{conn: conn} do
    {:ok, one} =
      Stonetop.create_session(%{"number" => 1, "title" => "Arrival", "notes" => "**Hi**"})

    {:ok, two} = Stonetop.create_session(%{"number" => 2, "notes" => ""})

    {:ok, view, _html} = live(conn, ~p"/stonetop/sessions")
    assert has_element?(view, "#session-#{two.id}")
    assert has_element?(view, "#session-earlier")
    refute has_element?(view, "#session-later")

    view |> element("#session-link-#{one.id}") |> render_click()
    assert has_element?(view, "#session-notes-body strong", "Hi")
  end

  test "unknown session shows a missing notice", %{conn: conn} do
    {:ok, _} = Stonetop.create_session(%{"number" => 1})
    {:ok, view, _html} = live(conn, ~p"/stonetop/sessions/nope")
    assert has_element?(view, "#session-missing")
  end
end
