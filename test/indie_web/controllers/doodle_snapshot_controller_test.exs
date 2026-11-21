defmodule IndieWeb.DoodleSnapshotControllerTest do
  use IndieWeb.ConnCase

  alias Indie.Doodle.CanvasServer

  setup do
    CanvasServer.reload()
    :ok
  end

  test "serves the current snapshot as an immutable png", %{conn: conn} do
    {hash, png} = CanvasServer.snapshot()
    conn = get(conn, "/doodle/snapshot/#{hash}")

    assert response(conn, 200) == png
    assert [content_type] = get_resp_header(conn, "content-type")
    assert content_type =~ "image/png"
    assert get_resp_header(conn, "cache-control") == ["public, max-age=31536000, immutable"]
  end

  test "redirects a stale hash to the current one without caching", %{conn: conn} do
    {hash, _png} = CanvasServer.snapshot()
    conn = get(conn, "/doodle/snapshot/0000000000000000")

    assert redirected_to(conn, 302) == "/doodle/snapshot/#{hash}"
    assert get_resp_header(conn, "cache-control") == ["no-cache"]
  end
end
