defmodule IndieWeb.StonetopFamilyLiveTest do
  use IndieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  alias Indie.Stonetop

  defp char(name) do
    {:ok, c} = Stonetop.create_character(%{"name" => name})
    c
  end

  defp family(_) do
    [maeve, aldric, pip] = Enum.map(~w(Maeve Aldric Pip), &char/1)
    {:ok, _} = Stonetop.create_parent_child(%{"parent_id" => maeve.id, "child_id" => aldric.id})
    {:ok, _} = Stonetop.create_parent_child(%{"parent_id" => aldric.id, "child_id" => pip.id})
    %{maeve: maeve, aldric: aldric, pip: pip}
  end

  describe "with no characters" do
    test "the relationship graph header links to the family trees", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/stonetop")
      assert has_element?(view, "#family-trees-link[href='/stonetop/family']")
    end

    test "shows the empty state", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/stonetop/family")
      assert has_element?(view, "#family-empty")
      refute html =~ "phoenixframework.org"
    end

    test "a character with no family can be chosen and shows alone", %{conn: conn} do
      loner = char("Loner")

      assert {:error, {:live_redirect, %{to: to}}} = live(conn, ~p"/stonetop/family")
      assert to == "/stonetop/family/#{loner.id}"

      {:ok, view, _html} = live(conn, to)
      assert has_element?(view, "#family-title", "Loner")
      assert has_element?(view, "#family-tree")
      view |> element("#family-picker-toggle") |> render_click()
      assert has_element?(view, "#family-picker-option-#{loner.id}")
    end
  end

  describe "with a family" do
    setup :family

    test "the landing page redirects to a random member", %{
      conn: conn,
      maeve: m,
      aldric: a,
      pip: p
    } do
      assert {:error, {:live_redirect, %{to: "/stonetop/family/" <> id}}} =
               live(conn, ~p"/stonetop/family")

      assert id in [m.id, a.id, p.id]
    end

    test "renders the tree page in the stonetop layout", %{conn: conn, aldric: a} do
      {:ok, view, html} = live(conn, ~p"/stonetop/family/#{a.id}")
      assert has_element?(view, "#family-title", "Aldric")
      assert has_element?(view, "#family-tree[phx-hook='FamilyTree']")
      assert html =~ "stonetop-body"
      refute html =~ "phoenixframework.org"
    end

    test "the person picker filters and links to members", %{conn: conn, aldric: a, pip: p} do
      {:ok, view, _html} = live(conn, ~p"/stonetop/family/#{a.id}")
      view |> element("#family-picker-toggle") |> render_click()
      view |> form("#family-picker-form", %{"q" => "pi"}) |> render_change()
      assert has_element?(view, "#family-picker-option-#{p.id}")
      refute has_element?(view, "#family-picker-option-#{a.id}")

      view |> element("#family-picker-option-#{p.id}") |> render_click()
      assert_patch(view, ~p"/stonetop/family/#{p.id}")
      assert has_element?(view, "#family-title", "Pip")
    end

    test "clicking a name in the tree patches to that person", %{conn: conn, aldric: a, maeve: m} do
      {:ok, view, _html} = live(conn, ~p"/stonetop/family/#{a.id}")
      render_hook(view, "select_person", %{"id" => m.id})
      assert_patch(view, ~p"/stonetop/family/#{m.id}")
    end

    test "an unknown id shows not found", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/stonetop/family/#{Ecto.UUID.generate()}")
      assert has_element?(view, "#family-empty")
    end
  end
end
