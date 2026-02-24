defmodule IndieWeb.DoodleCanvasComponent do
  use IndieWeb, :live_component

  alias Indie.Doodle

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(_assigns, socket) do
    # Load all pixels from database only on first render
    socket =
      if !Map.has_key?(socket.assigns, :pixels_loaded) do
        pixels = Doodle.list_pixels()

        socket
        |> assign(:doodle_help_open, false)
        |> assign(:pixels_loaded, true)
        |> then(fn socket ->
          if connected?(socket) do
            push_event(socket, "load-pixels", %{pixels: format_pixels(pixels)})
          else
            socket
          end
        end)
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("open_doodle_help", _, socket) do
    {:noreply, assign(socket, :doodle_help_open, true)}
  end

  @impl true
  def handle_event("close_doodle_help", _, socket) do
    {:noreply, assign(socket, :doodle_help_open, false)}
  end

  @impl true
  def handle_event("save_pixels", %{"pixels" => pixels}, socket) do
    # Save to database and get results (saved and deleted pixels)
    result = Doodle.save_pixels(pixels)

    # Broadcast saved pixels to all other clients (not including sender)
    if result.saved != [] do
      Phoenix.PubSub.broadcast_from(
        Indie.PubSub,
        self(),
        "doodle:pixels",
        {:new_pixels, result.saved}
      )
    end

    # Broadcast deleted pixels to all other clients (not including sender)
    if result.deleted != [] do
      Phoenix.PubSub.broadcast_from(
        Indie.PubSub,
        self(),
        "doodle:pixels",
        {:deleted_pixels, result.deleted}
      )
    end

    {:noreply, socket}
  end

  # Helper function to format pixels for JSON
  defp format_pixels(pixels) do
    Enum.map(pixels, fn p -> %{x: p.x, y: p.y, color: p.color} end)
  end
end
