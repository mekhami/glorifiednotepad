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
    assert_patch(view, ~p"/stonetop/sessions/arrival")
    assert has_element?(view, "#session-notes-body strong", "Hi")
  end

  test "finds sessions by title slug, fallback slug, or old id", %{conn: conn} do
    {:ok, one} = Stonetop.create_session(%{"number" => 1, "title" => "Éclair Road!"})
    {:ok, two} = Stonetop.create_session(%{"number" => 2})

    {:ok, view, _html} = live(conn, ~p"/stonetop/sessions/eclair-road")
    assert has_element?(view, "#session-#{one.id}")

    {:ok, view, _html} = live(conn, ~p"/stonetop/sessions/session-2")
    assert has_element?(view, "#session-#{two.id}")

    {:ok, view, _html} = live(conn, ~p"/stonetop/sessions/#{one.id}")
    assert has_element?(view, "#session-#{one.id}")
  end

  test "unknown session shows a missing notice", %{conn: conn} do
    {:ok, _} = Stonetop.create_session(%{"number" => 1})
    {:ok, view, _html} = live(conn, ~p"/stonetop/sessions/nope")
    assert has_element?(view, "#session-missing")
  end

  test "marks character mentions with their description", %{conn: conn} do
    {:ok, _} =
      Stonetop.create_character(%{
        "name" => "Lewela",
        "description" => "A sharp-eyed hunter",
        "tags" => ["pc"]
      })

    {:ok, _} =
      Stonetop.create_session(%{
        "number" => 1,
        "notes" => "Lewela went north. [Lewela](https://example.com) waved. Lewelan didn't."
      })

    {:ok, view, _html} = live(conn, ~p"/stonetop/sessions")

    assert has_element?(
             view,
             ~s(#session-notes-body .character-mention[data-kind="pc"][data-description="A sharp-eyed hunter"]),
             "Lewela"
           )

    refute has_element?(view, "#session-notes-body a .character-mention")
    html = view |> element("#session-notes-body") |> render()
    assert length(String.split(html, "character-mention")) == 2
  end
end
