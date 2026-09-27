defmodule IndieWeb.StonetopLive do
  use IndieWeb, :live_view

  alias Indie.Stonetop

  @impl true
  def mount(_params, _session, socket) do
    graph_data = Stonetop.get_graph_data()

    {:ok,
     socket
     |> assign(:selected_character, nil)
     |> push_event("load_graph", %{nodes: graph_data.nodes, edges: graph_data.edges})}
  end

  @impl true
  def handle_event("select_character", %{"id" => id, "x" => x, "y" => y}, socket) do
    character = Stonetop.get_character(id)
    relationships = Stonetop.get_relationships_for_character(id)

    {:noreply,
     socket
     |> assign(:selected_character, character)
     |> assign(:character_relationships, relationships)
     |> assign(:popup_x, x)
     |> assign(:popup_y, y)}
  end

  @impl true
  def handle_event("close_detail", _, socket) do
    {:noreply, assign(socket, :selected_character, nil)}
  end
end