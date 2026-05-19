defmodule Indie.Doodle.AnimationServer do
  use GenServer

  alias Indie.Doodle

  @fps 4
  @tick_ms div(1000, @fps)

  def start_link(animation) do
    GenServer.start_link(
      __MODULE__,
      animation,
      name: {:via, Registry, {Indie.Doodle.AnimationRegistry, animation.id}}
    )
  end

  @impl true
  def init(animation) do
    pixels_by_frame = Doodle.get_animation_pixels(animation.id)
    schedule_tick()

    state = %{
      animation_id: animation.id,
      frame_count: animation.frame_count,
      current_frame: 0,
      pixels_by_frame: pixels_by_frame
    }

    {:ok, state}
  end

  @impl true
  def handle_info(:tick, state) do
    next_frame = rem(state.current_frame + 1, state.frame_count)
    pixels = Map.get(state.pixels_by_frame, next_frame, [])

    Phoenix.PubSub.broadcast(
      Indie.PubSub,
      "doodle:pixels",
      {:animation_frame, state.animation_id, next_frame, pixels}
    )

    schedule_tick()
    {:noreply, %{state | current_frame: next_frame}}
  end

  @impl true
  def handle_info(:reload_pixels, state) do
    pixels_by_frame =
      try do
        Doodle.get_animation_pixels(state.animation_id)
      rescue
        _ -> state.pixels_by_frame
      end

    {:noreply, %{state | pixels_by_frame: pixels_by_frame}}
  end

  defp schedule_tick do
    Process.send_after(self(), :tick, @tick_ms)
  end
end
