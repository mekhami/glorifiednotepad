defmodule IndieWeb.DoodleCanvasSnapshotTest do
  use IndieWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Indie.Doodle.CanvasServer

  test "the first HTML already contains the board snapshot", %{conn: conn} do
    CanvasServer.reload()
    {hash, _png} = CanvasServer.snapshot()

    conn = get(conn, "/")

    assert html_response(conn, 200) =~ ~s(src="/doodle/snapshot/#{hash}")
    {:ok, view, _html} = live(conn)
    assert has_element?(view, "#doodle-snapshot-img")
  end
end
