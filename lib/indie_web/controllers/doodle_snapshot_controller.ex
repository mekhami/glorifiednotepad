defmodule IndieWeb.DoodleSnapshotController do
  use IndieWeb, :controller

  alias Indie.Doodle.CanvasServer

  def show(conn, %{"hash" => hash}) do
    case CanvasServer.snapshot() do
      {^hash, png} ->
        conn
        |> put_resp_header("cache-control", "public, max-age=31536000, immutable")
        |> put_resp_content_type("image/png")
        |> send_resp(200, png)

      {current, _png} ->
        conn
        |> put_resp_header("cache-control", "no-cache")
        |> redirect(to: "/doodle/snapshot/#{current}")

      nil ->
        send_resp(conn, 404, "")
    end
  end
end
