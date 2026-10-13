defmodule IndieWeb.StonetopFamilyLive do
  use IndieWeb, :live_view

  alias Indie.Stonetop

  @impl true
  def mount(params, _session, socket) do
    case {params, Stonetop.random_character()} do
      {%{"id" => _}, _} ->
        {:ok, assign_defaults(socket)}

      {_, nil} ->
        {:ok, assign_defaults(socket)}

      {_, member} ->
        {:ok, push_navigate(socket, to: ~p"/stonetop/family/#{member.id}")}
    end
  end

  defp assign_defaults(socket) do
    members = Stonetop.list_characters()

    socket
    |> assign(:page_title, "Family Tree")
    |> assign(:members, members)
    |> assign(:tree, nil)
    |> assign(:focus, nil)
    |> assign(:picker_open, false)
    |> assign(:query, "")
    |> assign(:matches, members)
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    case Stonetop.get_family_tree(id) do
      nil ->
        {:noreply, socket |> assign(:tree, nil) |> assign(:focus, nil)}

      tree ->
        focus = Enum.find(tree.nodes, &(&1.id == tree.focus_id))

        {:noreply,
         socket
         |> assign(:tree, tree)
         |> assign(:focus, focus)
         |> assign(:page_title, "The kin of #{focus.name}")
         |> assign(:picker_open, false)
         |> push_event("family_tree:render", tree)}
    end
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def handle_event("toggle_picker", _, socket) do
    {:noreply,
     socket
     |> assign(:picker_open, !socket.assigns.picker_open)
     |> assign(:query, "")
     |> assign(:matches, socket.assigns.members)}
  end

  def handle_event("close_picker", _, socket) do
    {:noreply, assign(socket, :picker_open, false)}
  end

  def handle_event("search", %{"q" => q}, socket) do
    needle = q |> String.trim() |> String.downcase()

    matches =
      Enum.filter(socket.assigns.members, fn m ->
        String.contains?(String.downcase(m.name), needle)
      end)

    {:noreply, socket |> assign(:query, q) |> assign(:matches, matches)}
  end

  def handle_event("select_person", %{"id" => id}, socket) do
    {:noreply, push_patch(socket, to: ~p"/stonetop/family/#{id}")}
  end
end
