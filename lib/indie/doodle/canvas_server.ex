defmodule Indie.Doodle.CanvasServer do
  @moduledoc """
  GenServer cache for canvas pixels and animations.

  Loads all data from DB once on startup, then maintains state
  incrementally as pixels/animations are saved. All reads are O(1).
  DB writes still go through Doodle context — this is a read cache only.
  """
  use GenServer

  alias Indie.Doodle

  ## Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @doc "Returns pre-formatted pixel list — O(1)."
  def get_pixels do
    GenServer.call(__MODULE__, :get_pixels)
  end

  @doc "Returns pre-formatted animation list with frames — O(1)."
  def get_animations do
    GenServer.call(__MODULE__, :get_animations)
  end

  @doc """
  Updates cache after static pixels are saved/deleted.
  `saved` — list of maps with at least :x, :y, :color keys.
  `deleted` — list of maps with at least :x, :y keys.
  """
  def update_pixels(saved, deleted) do
    GenServer.cast(__MODULE__, {:update_pixels, saved, deleted})
  end

  @doc """
  Updates frame data for an existing animation in the cache.
  Use when animation pixels changed but animation metadata (bounds/frame_count)
  did not change (e.g. static pixel overlaid onto animation region).
  `formatted_frames` — %{frame_idx => [%{x, y, color}]}.
  """
  def update_animation_frames(animation_id, formatted_frames) do
    GenServer.cast(__MODULE__, {:update_animation_frames, animation_id, formatted_frames})
  end

  @doc """
  Inserts or updates an animation and its frame data in the cache.
  Use after save_animation to keep metadata (frame_count) in sync.
  `animation` — Animation struct with id, x1, y1, x2, y2, frame_count fields.
  `formatted_frames` — %{frame_idx => [%{x, y, color}]}.
  """
  def upsert_animation(animation, formatted_frames) do
    GenServer.cast(__MODULE__, {:upsert_animation, animation, formatted_frames})
  end

  @doc "Removes an animation and its frames from the cache."
  def remove_animation(animation_id) do
    GenServer.cast(__MODULE__, {:remove_animation, animation_id})
  end

  @doc "Reloads state from DB. Used for test isolation."
  def reload do
    GenServer.call(__MODULE__, :reload)
  end

  ## Server Callbacks

  @impl true
  def init(_) do
    {:ok, load_initial_state()}
  end

  @impl true
  def handle_call(:get_pixels, _from, state) do
    {:reply, state.formatted_pixels, state}
  end

  @impl true
  def handle_call(:get_animations, _from, state) do
    {:reply, state.formatted_animations, state}
  end

  @impl true
  def handle_call(:reload, _from, _state) do
    {:reply, :ok, load_initial_state()}
  end

  @impl true
  def handle_cast({:update_pixels, saved, deleted}, state) do
    pixel_map =
      saved
      |> Enum.reduce(state.pixel_map, fn p, acc ->
        Map.put(acc, "#{p.x},#{p.y}", %{x: p.x, y: p.y, color: p.color})
      end)
      |> then(fn acc ->
        Enum.reduce(deleted, acc, fn p, m -> Map.delete(m, "#{p.x},#{p.y}") end)
      end)

    {:noreply, %{state | pixel_map: pixel_map, formatted_pixels: Map.values(pixel_map)}}
  end

  @impl true
  def handle_cast({:update_animation_frames, animation_id, formatted_frames}, state) do
    # No-op if animation not in cache (e.g. created after server start, save_animation not yet called)
    if Map.has_key?(state.animations_map, animation_id) do
      animation_pixels = Map.put(state.animation_pixels, animation_id, formatted_frames)
      formatted_animations = build_formatted_animations(state.animations_map, animation_pixels)

      {:noreply,
       %{state | animation_pixels: animation_pixels, formatted_animations: formatted_animations}}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:upsert_animation, animation, formatted_frames}, state) do
    animations_map = Map.put(state.animations_map, animation.id, animation)
    animation_pixels = Map.put(state.animation_pixels, animation.id, formatted_frames)
    formatted_animations = build_formatted_animations(animations_map, animation_pixels)

    {:noreply,
     %{
       state
       | animations_map: animations_map,
         animation_pixels: animation_pixels,
         formatted_animations: formatted_animations
     }}
  end

  @impl true
  def handle_cast({:remove_animation, animation_id}, state) do
    animations_map = Map.delete(state.animations_map, animation_id)
    animation_pixels = Map.delete(state.animation_pixels, animation_id)
    formatted_animations = build_formatted_animations(animations_map, animation_pixels)

    {:noreply,
     %{
       state
       | animations_map: animations_map,
         animation_pixels: animation_pixels,
         formatted_animations: formatted_animations
     }}
  end

  ## Private

  defp load_initial_state do
    pixels = Doodle.list_pixels()
    animations = Doodle.list_animations()
    animation_pixels = Doodle.get_all_animation_pixels()

    pixel_map = Map.new(pixels, fn p -> {"#{p.x},#{p.y}", %{x: p.x, y: p.y, color: p.color}} end)
    animations_map = Map.new(animations, fn a -> {a.id, a} end)
    formatted_animations = build_formatted_animations(animations_map, animation_pixels)

    %{
      pixel_map: pixel_map,
      formatted_pixels: Map.values(pixel_map),
      animations_map: animations_map,
      animation_pixels: animation_pixels,
      formatted_animations: formatted_animations
    }
  end

  defp build_formatted_animations(animations_map, animation_pixels) do
    Enum.map(animations_map, fn {_id, a} ->
      anim_frames = Map.get(animation_pixels, a.id, %{})

      %{
        id: a.id,
        x1: a.x1,
        y1: a.y1,
        x2: a.x2,
        y2: a.y2,
        frame_count: a.frame_count,
        frames: anim_frames
      }
    end)
  end
end
