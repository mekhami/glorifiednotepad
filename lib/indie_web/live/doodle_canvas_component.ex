defmodule IndieWeb.DoodleCanvasComponent do
  use IndieWeb, :live_component

  alias Indie.Doodle

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(_assigns, socket) do
    socket =
      if !Map.has_key?(socket.assigns, :pixels_loaded) do
        pixels = Doodle.list_pixels()
        animations = Doodle.list_animations()

        socket
        |> assign(:doodle_help_open, false)
        |> assign(:pixels_loaded, true)
        |> then(fn socket ->
          if connected?(socket) do
            socket
            |> push_event("load-pixels", %{pixels: format_pixels(pixels)})
            |> push_event("load-animations", %{animations: format_animations(animations)})
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
    result = Doodle.save_pixels(pixels)

    if result.saved != [] do
      Phoenix.PubSub.broadcast_from(
        Indie.PubSub,
        self(),
        "doodle:pixels",
        {:new_pixels, result.saved}
      )
    end

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

  @impl true
  def handle_event("create_animation", %{"x1" => x1, "y1" => y1, "x2" => x2, "y2" => y2}, socket) do
    attrs = %{x1: x1, y1: y1, x2: x2, y2: y2, frame_count: 1, fps: 4}

    case Doodle.create_animation(attrs) do
      {:ok, animation} ->
        {:reply, %{animation_id: animation.id}, socket}

      {:error, _changeset} ->
        {:reply, %{error: "region too large or invalid"}, socket}
    end
  end

  @impl true
  def handle_event("save_animation", %{"animation_id" => animation_id, "frames" => frames}, socket) do
    animation = Doodle.get_animation!(animation_id)
    frame_count = length(frames)
    {:ok, updated_animation} = Doodle.update_animation(animation, %{frame_count: frame_count})

    Doodle.save_animation_frames(animation_id, frames)
    Indie.Doodle.AnimationSupervisor.start_animation(updated_animation)

    {:noreply, socket}
  end

  @impl true
  def handle_event("delete_animation", %{"animation_id" => animation_id}, socket) do
    Indie.Doodle.AnimationSupervisor.stop_animation(animation_id)
    Doodle.delete_animation(animation_id)

    {:noreply, socket}
  end

  defp format_pixels(pixels) do
    Enum.map(pixels, fn p -> %{x: p.x, y: p.y, color: p.color} end)
  end

  defp format_animations(animations) do
    Enum.map(animations, fn a ->
      frame0_pixels =
        Doodle.get_animation_pixels(a.id)
        |> Map.get(0, [])

      %{
        id: a.id,
        x1: a.x1,
        y1: a.y1,
        x2: a.x2,
        y2: a.y2,
        frame_count: a.frame_count,
        frame0_pixels: frame0_pixels
      }
    end)
  end
end
