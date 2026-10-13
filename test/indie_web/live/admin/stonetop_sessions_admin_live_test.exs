defmodule IndieWeb.Admin.StonetopSessionsAdminLiveTest do
  use IndieWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  alias Indie.Stonetop

  setup %{conn: conn} do
    old_username = System.get_env("ADMIN_USERNAME")
    old_password = System.get_env("ADMIN_PASSWORD")
    System.put_env("ADMIN_USERNAME", "testadmin")
    System.put_env("ADMIN_PASSWORD", "testpass")

    on_exit(fn ->
      restore_env("ADMIN_USERNAME", old_username)
      restore_env("ADMIN_PASSWORD", old_password)
    end)

    auth = "Basic " <> Base.encode64("testadmin:testpass")
    {:ok, conn: Plug.Conn.put_req_header(conn, "authorization", auth)}
  end

  defp restore_env(key, nil), do: System.delete_env(key)
  defp restore_env(key, value), do: System.put_env(key, value)

  test "requires basic auth" do
    assert build_conn() |> get("/admin/stonetop/sessions") |> Map.get(:status) == 401
  end

  test "creates a session", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/stonetop/sessions")
    view |> element("#new-session") |> render_click()
    assert has_element?(view, "#session-form")

    view
    |> form("#session-form", session: %{title: "The Hillfolk", notes: "They came."})
    |> render_submit()

    assert [%{number: 1, title: "The Hillfolk", notes: "They came."} = s] =
             Stonetop.list_sessions()

    assert_patch(view, ~p"/admin/stonetop/sessions")
    assert has_element?(view, "#admin-session-#{s.id}")
    assert has_element?(view, "#session-admin-placeholder")
  end

  test "edits and deletes a session", %{conn: conn} do
    {:ok, s} = Stonetop.create_session(%{"number" => 3})
    {:ok, view, _html} = live(conn, ~p"/admin/stonetop/sessions?id=#{s.id}")

    view |> form("#session-form", session: %{notes: "Edited"}) |> render_submit()
    assert Stonetop.get_session(s.id).notes == "Edited"

    view |> element("#admin-session-#{s.id}") |> render_click()
    view |> element("#delete-session") |> render_click()
    assert Stonetop.list_sessions() == []
  end

  test "rejects a duplicate number", %{conn: conn} do
    {:ok, _} = Stonetop.create_session(%{"number" => 1})
    {:ok, view, _html} = live(conn, ~p"/admin/stonetop/sessions?id=new")

    html = view |> form("#session-form", session: %{number: 1}) |> render_submit()
    assert html =~ "already has notes"
  end
end
