defmodule IndieWeb.Admin.StonetopFamilyAdminLive do
  use IndieWeb, :live_view

  alias Indie.Stonetop
  alias Indie.Stonetop.{Character, ParentChild, Partnership}

  @roles ~w(parent partner child)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Stonetop Families")
     |> assign(:query, "")
     |> assign(:selected, nil)
     |> assign(:kin, nil)
     |> assign(:picker_role, nil)
     |> assign(:picker_form, nil)
     |> assign(:picker_error, nil)
     |> assign(:show_character_modal, false)
     |> assign(:character_form, new_character_form())
     |> load_people()}
  end

  @impl true
  def handle_params(%{"person" => param}, _uri, socket) do
    case find_person(socket.assigns.characters, param) do
      nil ->
        {:noreply, push_patch(socket, to: ~p"/admin/stonetop/families")}

      character ->
        {:noreply, socket |> assign(:selected, character) |> close_picker() |> refresh_kin()}
    end
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket |> assign(:selected, nil) |> assign(:kin, nil) |> close_picker()}
  end

  # --- People list ---

  @impl true
  def handle_event("search_people", %{"q" => q}, socket) do
    {:noreply, assign(socket, :query, q)}
  end

  # --- Link picker ---

  def handle_event("open_picker", %{"role" => role}, socket) when role in @roles do
    params =
      if role == "partner",
        do: %{"person_id" => "", "status" => "married"},
        else: %{"person_id" => "", "kind" => "biological"}

    {:noreply,
     socket
     |> assign(:picker_role, role)
     |> assign(:picker_form, to_form(params, as: :link))
     |> assign(:picker_error, nil)}
  end

  def handle_event("close_picker", _, socket) do
    {:noreply, close_picker(socket)}
  end

  def handle_event("validate_link", %{"link" => params}, socket) do
    {:noreply, assign(socket, :picker_form, to_form(params, as: :link))}
  end

  def handle_event("save_link", %{"link" => %{"person_id" => ""} = params}, socket) do
    {:noreply,
     socket
     |> assign(:picker_form, to_form(params, as: :link))
     |> assign(:picker_error, "Choose a person first.")}
  end

  def handle_event("save_link", %{"link" => params}, socket) do
    me = socket.assigns.selected.id
    other = params["person_id"]

    result =
      case socket.assigns.picker_role do
        "parent" ->
          Stonetop.create_parent_child(%{
            "parent_id" => other,
            "child_id" => me,
            "kind" => params["kind"]
          })

        "child" ->
          Stonetop.create_parent_child(%{
            "parent_id" => me,
            "child_id" => other,
            "kind" => params["kind"]
          })

        "partner" ->
          Stonetop.create_partnership(%{
            "partner_a_id" => me,
            "partner_b_id" => other,
            "status" => params["status"]
          })
      end

    case result do
      {:ok, _} ->
        {:noreply, socket |> close_picker() |> load_people() |> refresh_kin()}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:picker_form, to_form(params, as: :link))
         |> assign(:picker_error, error_message(changeset))}
    end
  end

  # --- Editing existing links ---

  def handle_event("remove_link", %{"type" => "parent_child", "id" => id}, socket) do
    {:ok, _} = id |> Stonetop.get_parent_child!() |> Stonetop.delete_parent_child()
    {:noreply, socket |> load_people() |> refresh_kin()}
  end

  def handle_event("remove_link", %{"type" => "partnership", "id" => id}, socket) do
    {:ok, _} = id |> Stonetop.get_partnership!() |> Stonetop.delete_partnership()
    {:noreply, socket |> load_people() |> refresh_kin()}
  end

  def handle_event("cycle_link", %{"type" => "parent_child", "id" => id}, socket) do
    link = Stonetop.get_parent_child!(id)

    {:ok, _} =
      Stonetop.update_parent_child(link, %{"kind" => next(ParentChild.kinds(), link.kind)})

    {:noreply, refresh_kin(socket)}
  end

  def handle_event("cycle_link", %{"type" => "partnership", "id" => id}, socket) do
    link = Stonetop.get_partnership!(id)

    {:ok, _} =
      Stonetop.update_partnership(link, %{"status" => next(Partnership.statuses(), link.status)})

    {:noreply, refresh_kin(socket)}
  end

  # --- Quick-add character ---

  def handle_event("new_character", _, socket) do
    {:noreply,
     socket
     |> assign(:show_character_modal, true)
     |> assign(:character_form, new_character_form())}
  end

  def handle_event("close_character_modal", _, socket) do
    {:noreply, assign(socket, :show_character_modal, false)}
  end

  def handle_event("validate_character", %{"character" => params}, socket) do
    form =
      %Character{}
      |> Character.changeset(params)
      |> Map.put(:action, :validate)
      |> to_form(as: :character)

    {:noreply, assign(socket, :character_form, form)}
  end

  def handle_event("save_character", %{"character" => params}, socket) do
    case Stonetop.create_character(params) do
      {:ok, character} ->
        {:noreply,
         socket
         |> assign(:show_character_modal, false)
         |> load_people()
         |> push_patch(to: ~p"/admin/stonetop/families?person=#{Character.slug(character)}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :character_form, to_form(changeset, as: :character))}
    end
  end

  # --- Helpers ---

  defp load_people(socket) do
    family_ids = Stonetop.list_family_members() |> MapSet.new(& &1.id)

    socket
    |> assign(:characters, Stonetop.list_characters())
    |> assign(:family_ids, family_ids)
  end

  defp refresh_kin(%{assigns: %{selected: nil}} = socket), do: socket

  defp refresh_kin(socket) do
    id = socket.assigns.selected.id

    socket
    |> assign(:kin, Stonetop.get_kin(id))
    |> push_event("family_tree:render", Stonetop.get_family_tree(id))
  end

  # Characters are listed oldest-first for slug lookups so that, when two
  # names collide, the same person always wins (matching get_character_by_slug).
  defp find_person(characters, param) do
    characters
    |> Enum.sort_by(& &1.inserted_at, NaiveDateTime)
    |> Enum.find(&(&1.id == param or Character.slug(&1) == param))
  end

  defp close_picker(socket) do
    socket
    |> assign(:picker_role, nil)
    |> assign(:picker_form, nil)
    |> assign(:picker_error, nil)
  end

  defp new_character_form do
    %Character{} |> Character.changeset(%{"tags_input" => ""}) |> to_form(as: :character)
  end

  defp next(list, current) do
    idx = Enum.find_index(list, &(&1 == current)) || -1
    Enum.at(list, rem(idx + 1, length(list)))
  end

  defp error_message(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Map.values()
    |> List.flatten()
    |> Enum.join(", ")
  end

  defp visible_people(characters, query) do
    needle = query |> String.trim() |> String.downcase()
    Enum.filter(characters, &String.contains?(String.downcase(&1.name), needle))
  end

  # Candidates for the picker: everyone except the selected person and those
  # already linked in the chosen role.
  defp picker_options(characters, selected, kin, role) do
    taken =
      case role do
        "parent" -> kin.parents
        "partner" -> kin.partners
        "child" -> kin.children
      end
      |> MapSet.new(& &1.person.id)

    for c <- characters, c.id != selected.id, not MapSet.member?(taken, c.id), do: {c.name, c.id}
  end

  defp role_label("parent"), do: "Add a parent"
  defp role_label("partner"), do: "Add a partner"
  defp role_label("child"), do: "Add a child"

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :role, :string, required: true
  attr :entries, :list, required: true
  attr :type, :string, required: true
  attr :meta, :atom, required: true

  defp kin_slot(assigns) do
    ~H"""
    <section id={@id} class="kin-slot">
      <h3>{@title}</h3>
      <div class="kin-chips">
        <span :for={%{link: link, person: person} <- @entries} class="kin-chip">
          <.link patch={~p"/admin/stonetop/families?person=#{Character.slug(person)}"}>
            {person.name}
          </.link>
          <button
            type="button"
            id={"cycle-#{@type}-#{link.id}"}
            class="kin-chip-meta"
            phx-click="cycle_link"
            phx-value-type={@type}
            phx-value-id={link.id}
            title="Click to change"
          >
            {Map.get(link, @meta)}
          </button>
          <button
            type="button"
            id={"remove-#{@type}-#{link.id}"}
            class="kin-chip-remove"
            phx-click="remove_link"
            phx-value-type={@type}
            phx-value-id={link.id}
            data-confirm={"Remove #{person.name}?"}
            aria-label={"Remove #{person.name}"}
          >
            ×
          </button>
        </span>
        <span :if={@entries == []} class="kin-empty">none recorded</span>
        <button
          type="button"
          id={"add-#{@role}"}
          class="kin-add"
          phx-click="open_picker"
          phx-value-role={@role}
        >
          + add
        </button>
      </div>
    </section>
    """
  end
end
