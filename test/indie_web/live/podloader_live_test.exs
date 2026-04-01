defmodule IndieWeb.PodloaderLiveTest do
  use IndieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders the podloader page", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/podloader")

    assert has_element?(view, "#podloader-page")
    assert has_element?(view, "#download-btn")
  end

  test "download button links to the dmg file", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/podloader")

    assert html =~ "/downloads/podloader.dmg"
  end
end
