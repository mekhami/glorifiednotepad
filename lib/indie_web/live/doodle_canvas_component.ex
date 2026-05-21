defmodule IndieWeb.DoodleCanvasComponent do
  use IndieWeb, :live_component

  alias Indie.Doodle
  alias Indie.Doodle.CanvasServer

  @impl true
  def mount(socket) do
    {:ok, assign(socket, :doodle_help_open, false)}
  end

  @impl true
  def update(_assigns, socket) do
    socket =
      if connected?(socket) and !Map.has_key?(socket.assigns, :pixels_loaded) do
        formatted_pixels = CanvasServer.get_pixels()
        formatted_animations = CanvasServer.get_animations()

        socket
        |> assign(:pixels_loaded, true)
        |> push_event("load-pixels", %{pixels: formatted_pixels})
        |> push_event("load-animations", %{animations: formatted_animations})
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

    CanvasServer.update_pixels(result.saved, result.deleted)

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

    # For each animation that lost pixels to a static overwrite,
    # broadcast updated frames to other clients and push to this client
    # so their animationData doesn't keep rendering the deleted coords.
    socket =
      Enum.reduce(result.modified_animation_ids, socket, fn animation_id, acc ->
        pixels_by_frame = Doodle.get_animation_pixels(animation_id)
        formatted_frames = format_frames(pixels_by_frame)

        CanvasServer.update_animation_frames(animation_id, formatted_frames)

        Phoenix.PubSub.broadcast_from(
          Indie.PubSub,
          self(),
          "doodle:pixels",
          {:animation_updated, animation_id, formatted_frames}
        )

        push_event(acc, "reload-animation", %{
          animation_id: animation_id,
          frames: formatted_frames
        })
      end)

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
  def handle_event(
        "save_animation",
        %{"animation_id" => animation_id, "frames" => frames},
        socket
      ) do
    animation = Doodle.get_animation!(animation_id)
    frame_count = length(frames)
    {:ok, updated_animation} = Doodle.update_animation(animation, %{frame_count: frame_count})

    {:ok, %{deleted_animation_ids: deleted_ids}} =
      Doodle.save_animation_frames(updated_animation, frames)

    # Build frame data for broadcasts and reply
    pixels_by_frame = Doodle.get_animation_pixels(animation_id)
    formatted_frames = format_frames(pixels_by_frame)

    CanvasServer.upsert_animation(updated_animation, formatted_frames)

    Enum.each(deleted_ids, fn id -> CanvasServer.remove_animation(id) end)

    # Notify other clients of updated frames
    Phoenix.PubSub.broadcast_from(
      Indie.PubSub,
      self(),
      "doodle:pixels",
      {:animation_updated, animation_id, formatted_frames}
    )

    # Notify other clients of any auto-deleted animations
    Enum.each(deleted_ids, fn id ->
      Phoenix.PubSub.broadcast_from(
        Indie.PubSub,
        self(),
        "doodle:pixels",
        {:animation_deleted, id}
      )
    end)

    {:reply,
     %{
       ok: true,
       animation_id: animation_id,
       frames: formatted_frames,
       deleted_animation_ids: deleted_ids
     }, socket}
  end

  defp format_frames(pixels_by_frame) do
    Map.new(pixels_by_frame, fn {frame_idx, pixels} ->
      {frame_idx, Enum.map(pixels, fn p -> %{x: p.x, y: p.y, color: p.color} end)}
    end)
  end
end
