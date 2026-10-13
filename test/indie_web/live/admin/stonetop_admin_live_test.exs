defmodule IndieWeb.Admin.StonetopAdminLiveTest do
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

    conn =
      Plug.Conn.put_req_header(
        conn,
        "authorization",
        "Basic " <> Base.encode64("testadmin:testpass")
      )

    {:ok, conn: conn}
  end

  defp restore_env(key, nil), do: System.delete_env(key)
  defp restore_env(key, value), do: System.put_env(key, value)

  defp character(name, attrs \\ %{}) do
    {:ok, c} = Stonetop.create_character(Map.put(attrs, "name", name))
    c
  end

  test "requires basic auth" do
    assert build_conn() |> get("/admin/stonetop") |> Map.get(:status) == 401
  end

  test "lists characters and switches to relationships", %{conn: conn} do
    maeve = character("Maeve", %{"tags" => "pc, healer"})
    aldric = character("Aldric")

    {:ok, rel} =
      Stonetop.create_relationship(%{"source_id" => maeve.id, "target_id" => aldric.id})

    {:ok, view, _html} = live(conn, ~p"/admin/stonetop")
    assert has_element?(view, "#character-#{maeve.id}", "Maeve")
    assert has_element?(view, "#character-#{maeve.id} .tag", "healer")
    refute has_element?(view, "#relationships-panel")

    view |> element("#relationships-tab") |> render_click()
    assert has_element?(view, "#relationship-#{rel.id}", "Aldric")
    refute has_element?(view, "#characters-panel")
  end

  test "creates a character", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/stonetop")
    view |> element("#new-character") |> render_click()

    view
    |> form("#character-form", %{"character" => %{"name" => "Pip", "tags_input" => "npc, kid"}})
    |> render_submit()

    refute has_element?(view, "#character-modal")
    [pip] = Stonetop.list_characters()
    assert pip.tags == ["npc", "kid"]
    assert has_element?(view, "#character-#{pip.id}", "Pip")
  end

  test "edits a character, keeping its tags in the form", %{conn: conn} do
    maeve = character("Maeve", %{"tags" => "pc"})
    {:ok, view, _html} = live(conn, ~p"/admin/stonetop")
    view |> element("#edit-character-#{maeve.id}") |> render_click()
    assert has_element?(view, "#character-form input[value='pc']")

    view
    |> form("#character-form", %{"character" => %{"name" => "Maeve the Bold"}})
    |> render_submit()

    assert Stonetop.get_character!(maeve.id).name == "Maeve the Bold"
  end

  test "uploads a portrait to the uploads dir", %{conn: conn} do
    tmp = Path.join(System.tmp_dir!(), "indie-uploads-#{System.unique_integer([:positive])}")
    Application.put_env(:indie, :uploads_dir, tmp)

    on_exit(fn ->
      Application.delete_env(:indie, :uploads_dir)
      File.rm_rf!(tmp)
    end)

    maeve = character("Maeve")
    {:ok, view, _html} = live(conn, ~p"/admin/stonetop")
    view |> element("#edit-character-#{maeve.id}") |> render_click()

    avatar =
      file_input(view, "#character-form", :avatar, [
        %{name: "maeve.png", content: "fake png", type: "image/png"}
      ])

    render_upload(avatar, "maeve.png")
    view |> form("#character-form") |> render_submit()

    image_url = Stonetop.get_character!(maeve.id).image_url
    assert image_url =~ ~r"^#{maeve.id}/avatar-\d+\.png$"
    assert File.read!(Path.join([tmp, "stonetop", image_url])) == "fake png"
    assert has_element?(view, "#character-#{maeve.id} img[src='/uploads/stonetop/#{image_url}']")
  end

  test "deletes a character", %{conn: conn} do
    maeve = character("Maeve")
    {:ok, view, _html} = live(conn, ~p"/admin/stonetop")
    view |> element("#delete-character-#{maeve.id}") |> render_click()
    refute has_element?(view, "#character-#{maeve.id}")
    assert Stonetop.list_characters() == []
  end

  test "creates and edits a relationship", %{conn: conn} do
    maeve = character("Maeve")
    aldric = character("Aldric")
    {:ok, view, _html} = live(conn, ~p"/admin/stonetop")
    view |> element("#relationships-tab") |> render_click()
    view |> element("#new-relationship") |> render_click()

    view
    |> form("#relationship-form", %{
      "relationship" => %{
        "source_id" => maeve.id,
        "target_id" => aldric.id,
        "tags" => "rivals, kin"
      }
    })
    |> render_submit()

    [rel] = Stonetop.list_relationships()
    assert rel.tags == ["rivals", "kin"]

    view |> element("#edit-relationship-#{rel.id}") |> render_click()
    assert has_element?(view, "#relationship-form input[value='rivals, kin']")
  end
end
