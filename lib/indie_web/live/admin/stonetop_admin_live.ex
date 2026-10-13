defmodule IndieWeb.Admin.StonetopAdminLive do
  use IndieWeb, :live_view

  alias Indie.Stonetop
  alias Indie.Stonetop.{Character, Relationship}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:active_tab, "characters")
     |> assign(:modal, nil)
     |> assign(:editing, nil)
     |> assign(:form, nil)
     |> load_characters()
     |> load_relationships()
     |> allow_upload(:avatar,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 1,
       max_file_size: 8_000_000
     )}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket)
      when tab in ~w(characters relationships) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  def handle_event("close_modal", _, socket) do
    {:noreply, close_modal(socket)}
  end

  # --- Characters ---

  def handle_event("new_character", _, socket) do
    {:noreply, open_character(socket, %Character{})}
  end

  def handle_event("edit_character", %{"id" => id}, socket) do
    case Stonetop.get_character(id) do
      nil -> {:noreply, socket |> put_flash(:error, "Character not found") |> load_characters()}
      character -> {:noreply, open_character(socket, character)}
    end
  end

  def handle_event("validate_character", %{"character" => params}, socket) do
    changeset =
      socket.assigns.editing
      |> Character.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset, as: :character))}
  end

  def handle_event("save_character", %{"character" => params}, socket) do
    %{editing: character} = socket.assigns

    result =
      if character.id,
        do: Stonetop.update_character(character, params),
        else: Stonetop.create_character(params)

    case result do
      {:ok, saved} ->
        attach_avatar(socket, saved)

        {:noreply,
         socket
         |> put_flash(:info, if(character.id, do: "Character updated", else: "Character created"))
         |> reset_modal()
         |> load_characters()
         |> load_relationships()}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: :character))}
    end
  end

  def handle_event("cancel_avatar", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :avatar, ref)}
  end

  def handle_event("delete_character", %{"id" => id}, socket) do
    socket =
      case Stonetop.get_character(id) do
        nil ->
          put_flash(socket, :error, "Character not found")

        character ->
          {:ok, _} = Stonetop.delete_character(character)
          put_flash(socket, :info, "Character deleted")
      end

    {:noreply, socket |> load_characters() |> load_relationships()}
  end

  # --- Relationships ---

  def handle_event("new_relationship", _, socket) do
    {:noreply, open_relationship(socket, %Relationship{})}
  end

  def handle_event("edit_relationship", %{"id" => id}, socket) do
    case find_relationship(socket, id) do
      nil ->
        {:noreply, socket |> put_flash(:error, "Relationship not found") |> load_relationships()}

      relationship ->
        {:noreply, open_relationship(socket, relationship)}
    end
  end

  def handle_event("validate_relationship", %{"relationship" => params}, socket) do
    changeset =
      socket.assigns.editing
      |> Relationship.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset, as: :relationship))}
  end

  def handle_event("save_relationship", %{"relationship" => params}, socket) do
    %{editing: relationship} = socket.assigns

    result =
      if relationship.id,
        do: Stonetop.update_relationship(relationship, params),
        else: Stonetop.create_relationship(params)

    case result do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           if(relationship.id, do: "Relationship updated", else: "Relationship created")
         )
         |> close_modal()
         |> load_relationships()}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: :relationship))}
    end
  end

  def handle_event("delete_relationship", %{"id" => id}, socket) do
    socket =
      case find_relationship(socket, id) do
        nil ->
          put_flash(socket, :error, "Relationship not found")

        relationship ->
          {:ok, _} = Stonetop.delete_relationship(relationship)
          put_flash(socket, :info, "Relationship deleted")
      end

    {:noreply, load_relationships(socket)}
  end

  # --- Helpers ---

  defp load_characters(socket), do: assign(socket, :characters, Stonetop.list_characters())

  defp load_relationships(socket),
    do: assign(socket, :relationships, Stonetop.list_relationships())

  defp find_relationship(socket, id), do: Enum.find(socket.assigns.relationships, &(&1.id == id))

  defp open_character(socket, character) do
    params = %{"tags_input" => Enum.join(character.tags, ", ")}

    socket
    |> cancel_pending_avatar()
    |> assign(:modal, :character)
    |> assign(:editing, character)
    |> assign(:form, to_form(Character.changeset(character, params), as: :character))
  end

  defp open_relationship(socket, relationship) do
    socket
    |> assign(:modal, :relationship)
    |> assign(:editing, relationship)
    |> assign(:form, to_form(Relationship.changeset(relationship, %{}), as: :relationship))
  end

  defp close_modal(socket) do
    socket
    |> cancel_pending_avatar()
    |> reset_modal()
  end

  # After a save the avatar entry has already been consumed, so there is nothing to cancel.
  defp reset_modal(socket) do
    socket
    |> assign(:modal, nil)
    |> assign(:editing, nil)
    |> assign(:form, nil)
  end

  defp cancel_pending_avatar(socket) do
    Enum.reduce(socket.assigns.uploads.avatar.entries, socket, fn entry, socket ->
      cancel_upload(socket, :avatar, entry.ref)
    end)
  end

  # Avatars live at <uploads_dir>/stonetop/<character_id>/<file> and are stored
  # on the character relative to /uploads/stonetop/.
  defp attach_avatar(socket, character) do
    paths =
      consume_uploaded_entries(socket, :avatar, fn %{path: tmp}, entry ->
        dir = Path.join([Indie.uploads_dir(), "stonetop", character.id])

        filename =
          "avatar-#{System.unique_integer([:positive])}#{Path.extname(entry.client_name)}"

        File.mkdir_p!(dir)
        File.cp!(tmp, Path.join(dir, filename))
        {:ok, "#{character.id}/#{filename}"}
      end)

    case paths do
      [path | _] -> Stonetop.update_character(character, %{"image_url" => path})
      [] -> :ok
    end
  end

  defp tags_value(form) do
    case form[:tags].value do
      tags when is_list(tags) -> Enum.join(tags, ", ")
      tags -> tags
    end
  end

  defp avatar_src(%Character{image_url: url}) when is_binary(url), do: "/uploads/stonetop/" <> url
  defp avatar_src(_), do: nil

  defp upload_error(:too_large), do: "That image is too big (8MB max)"
  defp upload_error(:not_accepted), do: "Use a jpg, png, or webp"
  defp upload_error(:too_many_files), do: "Just one image, please"
  defp upload_error(_), do: "Couldn't use that file"
end
