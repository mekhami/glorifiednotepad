defmodule IndieWeb.Admin.StonetopAdminLive do
  use IndieWeb, :live_view

  alias Indie.Stonetop
  alias Indie.Stonetop.{Character, Relationship}

  @impl true
  def mount(_params, _session, socket) do
    characters = Stonetop.list_characters()
    relationships = Stonetop.list_relationships()

    socket =
      socket
      |> assign(:characters, characters)
      |> assign(:relationships, relationships)
      |> assign(:active_tab, "characters")
      |> assign(:character_form, to_form(Character.changeset(%Character{}, %{}), as: :character))
      |> assign(:relationship_form, to_form(Relationship.changeset(%Relationship{}, %{}), as: :relationship))
      |> assign(:editing_character, nil)
      |> assign(:editing_relationship, nil)
      |> assign(:show_character_modal, false)
      |> assign(:show_relationship_modal, false)
      |> assign(:avatar_entries, [])

    {:ok, socket}
  end

  defp character_form(_socket) do
    to_form(Character.changeset(%Character{}, %{}), as: :character)
  end

  defp relationship_form(_socket) do
    to_form(Relationship.changeset(%Relationship{}, %{}), as: :relationship)
  end

  defp character_form(_socket, character) do
    to_form(Character.changeset(character, %{}), as: :character)
  end

  defp relationship_form(_socket, relationship) do
    to_form(Relationship.changeset(relationship, %{}), as: :relationship)
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  # --- Character CRUD ---

  @impl true
  def handle_event("open_character_modal", %{"id" => id}, socket) do
    character = Stonetop.get_character!(id)
    {:noreply,
     socket
     |> assign(:editing_character, character)
     |> assign(:character_form, character_form(socket, character))
     |> assign(:show_character_modal, true)
     |> assign(:avatar_entries, [])}
  end

  @impl true
  def handle_event("new_character", _, socket) do
    {:noreply,
     socket
     |> assign(:editing_character, nil)
     |> assign(:character_form, character_form(socket))
     |> assign(:show_character_modal, true)
     |> assign(:avatar_entries, [])}
  end

  @impl true
  def handle_event("close_character_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:show_character_modal, false)
     |> assign(:editing_character, nil)
     |> assign(:character_form, character_form(socket))
     |> assign(:avatar_entries, [])}
  end

  @impl true
  def handle_event("validate_character", %{"character" => params}, socket) do
    changeset =
      if socket.assigns.editing_character do
        Character.changeset(socket.assigns.editing_character, params)
      else
        Character.changeset(%Character{}, params)
      end
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :character_form, to_form(changeset, as: :character))}
  end

  @impl true
  def handle_event("save_character", %{"character" => params}, socket) do
    avatar = get_avatar_upload(socket)
    attrs = process_character_params(params, avatar)

    if socket.assigns.editing_character do
      case Stonetop.update_character(socket.assigns.editing_character, attrs) do
        {:ok, _character} ->
          {:noreply,
           socket
           |> put_flash(:info, "Character updated")
           |> assign(:show_character_modal, false)
           |> assign(:editing_character, nil)
           |> assign(:characters, Stonetop.list_characters())}
        {:error, changeset} ->
          {:noreply, assign(socket, :character_form, to_form(changeset, as: :character))}
      end
    else
      case Stonetop.create_character(attrs) do
        {:ok, _character} ->
          {:noreply,
           socket
           |> put_flash(:info, "Character created")
           |> assign(:show_character_modal, false)
           |> assign(:characters, Stonetop.list_characters())}
        {:error, changeset} ->
          {:noreply, assign(socket, :character_form, to_form(changeset, as: :character))}
      end
    end
  end

  @impl true
  def handle_event("delete_character", %{"id" => id}, socket) do
    case Stonetop.get_character(id) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "Character not found")
         |> assign(:characters, Stonetop.list_characters())}

      character ->
        Stonetop.delete_character(character)
        {:noreply,
         socket
         |> put_flash(:info, "Character deleted")
         |> assign(:characters, Stonetop.list_characters())}
    end
  end

  # --- Relationship CRUD ---

  @impl true
  def handle_event("open_relationship_modal", %{"id" => id}, socket) do
    relationship = Stonetop.list_relationships() |> Enum.find(&(&1.id == id))

    if relationship do
      {:noreply,
       socket
       |> assign(:editing_relationship, relationship)
       |> assign(:relationship_form, relationship_form(socket, relationship))
       |> assign(:show_relationship_modal, true)}
    else
      {:noreply, put_flash(socket, :error, "Relationship not found")}
    end
  end

  @impl true
  def handle_event("new_relationship", _, socket) do
    {:noreply,
     socket
     |> assign(:editing_relationship, nil)
     |> assign(:relationship_form, relationship_form(socket))
     |> assign(:show_relationship_modal, true)}
  end

  @impl true
  def handle_event("close_relationship_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:show_relationship_modal, false)
     |> assign(:editing_relationship, nil)
     |> assign(:relationship_form, relationship_form(socket))}
  end

  @impl true
  def handle_event("validate_relationship", %{"relationship" => params}, socket) do
    changeset =
      if socket.assigns.editing_relationship do
        Relationship.changeset(socket.assigns.editing_relationship, params)
      else
        Relationship.changeset(%Relationship{}, params)
      end
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :relationship_form, to_form(changeset, as: :relationship))}
  end

  @impl true
  def handle_event("save_relationship", %{"relationship" => params}, socket) do
    attrs = process_relationship_params(params)

    if socket.assigns.editing_relationship do
      case Stonetop.update_relationship(socket.assigns.editing_relationship, attrs) do
        {:ok, _relationship} ->
          {:noreply,
           socket
           |> put_flash(:info, "Relationship updated")
           |> assign(:show_relationship_modal, false)
           |> assign(:editing_relationship, nil)
           |> assign(:relationships, Stonetop.list_relationships())}
        {:error, changeset} ->
          {:noreply, assign(socket, :relationship_form, to_form(changeset, as: :relationship))}
      end
    else
      case Stonetop.create_relationship(attrs) do
        {:ok, _relationship} ->
          {:noreply,
           socket
           |> put_flash(:info, "Relationship created")
           |> assign(:show_relationship_modal, false)
           |> assign(:relationships, Stonetop.list_relationships())}
        {:error, changeset} ->
          {:noreply, assign(socket, :relationship_form, to_form(changeset, as: :relationship))}
      end
    end
  end

  @impl true
  def handle_event("delete_relationship", %{"id" => id}, socket) do
    relationship = Stonetop.list_relationships() |> Enum.find(&(&1.id == id))

    if relationship do
      Stonetop.delete_relationship(relationship)
      {:noreply,
       socket
       |> put_flash(:info, "Relationship deleted")
       |> assign(:relationships, Stonetop.list_relationships())}
    else
      {:noreply, put_flash(socket, :error, "Relationship not found")}
    end
  end

  # --- Upload handling ---

  @impl true
  def handle_event("allow_upload", %{"avatar" => _}, socket) do
    {:noreply, allow_upload(socket, :avatar, accept: ~w(.jpg .jpeg .png .webp), max_entries: 1)}
  end

  @impl true
  def handle_event("cancel_upload", %{"avatar-ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :avatar, ref)}
  end

  @impl true
  def handle_event("progress_upload", _, socket) do
    {:noreply, socket}
  end

  defp process_character_params(params, avatar) do
    attrs = Map.put(params, "tags", parse_tags(params["tags"]))
    if avatar do
      Map.put(attrs, "image_url", avatar.path)
    else
      attrs
    end
  end

  defp process_relationship_params(params) do
    Map.put(params, "tags", parse_tags(params["tags"]))
  end

  defp parse_tags(tags_string) when is_binary(tags_string) do
    tags_string
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end
  defp parse_tags(nil), do: []

  defp get_avatar_upload(socket) do
    case consume_uploaded_entries(socket, :avatar, fn %{} = entry ->
      # Generate path: uploads/stonetop/{character_id}/{filename}
      character_id =
        case socket.assigns.editing_character do
          nil -> Ecto.UUID.generate()
          character -> character.id
        end

      ext = Path.extname(entry.client_name)
      filename = "avatar#{ext}"
      dest_dir = Path.join("priv/static/uploads/stonetop", character_id)

      try do
        File.mkdir_p!(dest_dir)
        dest_path = Path.join(dest_dir, filename)
        File.cp!(entry.path, dest_path)
        %{path: "uploads/stonetop/#{character_id}/#{filename}"}
      rescue
        e in [File.Error, ErlangError] ->
          IO.inspect(e, label: "Upload failed")
          nil
      end
    end) do
      {[entry | _], _socket} -> entry
      _ -> nil
    end
  end
end