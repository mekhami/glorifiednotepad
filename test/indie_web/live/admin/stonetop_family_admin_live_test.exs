defmodule IndieWeb.Admin.StonetopFamilyAdminLiveTest do
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

    [maeve, aldric, pip] =
      Enum.map(~w(Maeve Aldric Pip), fn name ->
        {:ok, c} = Stonetop.create_character(%{"name" => name})
        c
      end)

    {:ok, conn: admin_conn(conn), maeve: maeve, aldric: aldric, pip: pip}
  end

  defp restore_env(key, nil), do: System.delete_env(key)
  defp restore_env(key, value), do: System.put_env(key, value)

  defp admin_conn(conn) do
    Plug.Conn.put_req_header(
      conn,
      "authorization",
      "Basic " <> Base.encode64("testadmin:testpass")
    )
  end

  test "requires basic auth" do
    assert build_conn() |> get("/admin/stonetop/families") |> Map.get(:status) == 401
  end

  test "renders in the admin layout, not the default phoenix one", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/admin/stonetop/families")
    assert has_element?(view, ".admin-container #family-people")
    assert has_element?(view, "#family-admin-placeholder")
    refute html =~ "phoenixframework.org"
  end

  test "selecting a person shows their kin editor", %{conn: conn, aldric: a} do
    {:ok, view, _html} = live(conn, ~p"/admin/stonetop/families")
    view |> element("#person-#{a.id}") |> render_click()
    assert_patch(view, ~p"/admin/stonetop/families?id=#{a.id}")
    assert has_element?(view, "#kin-editor h2", "Aldric")
    assert has_element?(view, "#family-preview[phx-hook='FamilyTree']")
  end

  test "filters the people list", %{conn: conn, aldric: a, pip: p} do
    {:ok, view, _html} = live(conn, ~p"/admin/stonetop/families")
    view |> form("#people-search-form", %{"q" => "pi"}) |> render_change()
    assert has_element?(view, "#person-#{p.id}")
    refute has_element?(view, "#person-#{a.id}")
  end

  test "adds and removes a parent", %{conn: conn, aldric: a, maeve: m} do
    {:ok, view, _html} = live(conn, ~p"/admin/stonetop/families?id=#{a.id}")
    view |> element("#add-parent") |> render_click()

    view
    |> form("#kin-link-form", %{"link" => %{"person_id" => m.id, "kind" => "adopted"}})
    |> render_submit()

    assert has_element?(view, "#kin-parents .kin-chip", "Maeve")
    assert has_element?(view, "#kin-parents .kin-chip", "adopted")
    [%{link: link}] = Stonetop.get_kin(a.id).parents

    view |> element("#remove-parent_child-#{link.id}") |> render_click()
    refute has_element?(view, "#kin-parents .kin-chip")
    assert Stonetop.get_kin(a.id).parents == []
  end

  test "adds a child and a partner, and cycles partner status", %{
    conn: conn,
    aldric: a,
    pip: p,
    maeve: m
  } do
    {:ok, view, _html} = live(conn, ~p"/admin/stonetop/families?id=#{a.id}")

    view |> element("#add-child") |> render_click()

    view
    |> form("#kin-link-form", %{"link" => %{"person_id" => p.id, "kind" => "biological"}})
    |> render_submit()

    assert has_element?(view, "#kin-children .kin-chip", "Pip")

    view |> element("#add-partner") |> render_click()

    view
    |> form("#kin-link-form", %{"link" => %{"person_id" => m.id, "status" => "married"}})
    |> render_submit()

    assert has_element?(view, "#kin-partners .kin-chip", "married")
    [%{link: partnership}] = Stonetop.get_kin(a.id).partners

    view |> element("#cycle-partnership-#{partnership.id}") |> render_click()
    assert has_element?(view, "#kin-partners .kin-chip", "partnered")
  end

  test "shows an error when a link would form a cycle", %{conn: conn, aldric: a, pip: p} do
    {:ok, _} = Stonetop.create_parent_child(%{"parent_id" => a.id, "child_id" => p.id})
    {:ok, view, _html} = live(conn, ~p"/admin/stonetop/families?id=#{a.id}")

    view |> element("#add-parent") |> render_click()

    view
    |> form("#kin-link-form", %{"link" => %{"person_id" => p.id, "kind" => "biological"}})
    |> render_submit()

    assert has_element?(view, "#kin-link-error", "own ancestor")
  end

  test "quick-adds a character and selects them", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/stonetop/families")
    view |> element("#new-character") |> render_click()

    view
    |> form("#quick-character-form", %{
      "character" => %{"name" => "Isolde", "tags_input" => "npc"}
    })
    |> render_submit()

    isolde = Enum.find(Stonetop.list_characters(), &(&1.name == "Isolde"))
    assert isolde.tags == ["npc"]
    assert_patch(view, ~p"/admin/stonetop/families?id=#{isolde.id}")
    assert has_element?(view, "#kin-editor h2", "Isolde")
  end
end
