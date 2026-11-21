defmodule Indie.Doodle.CanvasServer do
  @moduledoc """
  GenServer cache for canvas pixels and animations.

  Loads all data from DB once on startup, then maintains state
  incrementally as pixels/animations are saved. All reads are O(1).
  DB writes still go through Doodle context — this is a read cache only.

  Also refreshes itself from the database every 60s so that out-of-band
  changes (e.g. `Indie.Doodle.SeedLogo` run from another process) are picked up without restarting
  the server.
  """
  use GenServer

  @refresh_interval 60_000
  @snapshot_debounce 1_000
  @snapshot_table :doodle_snapshot

  alias Indie.Doodle
  alias Indie.Doodle.Snapshot

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

  @doc """
  Returns `{hash, png}` for the most recently built board snapshot, or nil
  before the first build. Reads ETS directly, so it never queues behind the server.
  """
  def snapshot do
    case :ets.lookup(@snapshot_table, :current) do
      [{:current, hash, png}] -> {hash, png}
      [] -> nil
    end
  end

  @doc "Builds and publishes the snapshot immediately. Used for test isolation."
  def rebuild_snapshot_now do
    GenServer.call(__MODULE__, :rebuild_snapshot_now, 30_000)
  end

  ## Server Callbacks

  @impl true
  def init(_) do
    :ets.new(@snapshot_table, [:named_table, :protected, read_concurrency: true])
    state = Map.merge(load_initial_state(), snapshot_bookkeeping())
    :timer.send_interval(@refresh_interval, self(), :refresh_from_db)
    {:ok, schedule_snapshot(state, 0)}
  end

  @impl true
  def handle_info(:refresh_from_db, state) do
    {:noreply, state |> Map.merge(load_initial_state()) |> schedule_snapshot()}
  end

  def handle_info(:build_snapshot, state) do
    seq = state.build_seq + 1
    parent = self()
    pixels = state.formatted_pixels
    animations = state.formatted_animations

    Task.start(fn -> send(parent, {:snapshot_built, seq, Snapshot.build(pixels, animations)}) end)

    {:noreply, %{state | snapshot_timer: nil, build_seq: seq}}
  end

  def handle_info({:snapshot_built, seq, png}, state) when seq > state.last_inserted_seq do
    publish_snapshot(png)
    {:noreply, %{state | last_inserted_seq: seq}}
  end

  def handle_info({:snapshot_built, _stale_seq, _png}, state), do: {:noreply, state}

  @impl true
  def handle_call(:get_pixels, _from, state) do
    {:reply, state.formatted_pixels, state}
  end

  @impl true
  def handle_call(:get_animations, _from, state) do
    {:reply, state.formatted_animations, state}
  end

  @impl true
  def handle_call(:reload, _from, state) do
    {:reply, :ok, state |> Map.merge(load_initial_state()) |> build_snapshot_now()}
  end

  def handle_call(:rebuild_snapshot_now, _from, state) do
    {:reply, :ok, build_snapshot_now(state)}
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

    {:noreply,
     schedule_snapshot(%{state | pixel_map: pixel_map, formatted_pixels: Map.values(pixel_map)})}
  end

  @impl true
  def handle_cast({:update_animation_frames, animation_id, formatted_frames}, state) do
    # No-op if animation not in cache (e.g. created after server start, save_animation not yet called)
    if Map.has_key?(state.animations_map, animation_id) do
      animation_pixels = Map.put(state.animation_pixels, animation_id, formatted_frames)
      formatted_animations = build_formatted_animations(state.animations_map, animation_pixels)

      {:noreply,
       schedule_snapshot(%{
         state
         | animation_pixels: animation_pixels,
           formatted_animations: formatted_animations
       })}
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
     schedule_snapshot(%{
       state
       | animations_map: animations_map,
         animation_pixels: animation_pixels,
         formatted_animations: formatted_animations
     })}
  end

  @impl true
  def handle_cast({:remove_animation, animation_id}, state) do
    animations_map = Map.delete(state.animations_map, animation_id)
    animation_pixels = Map.delete(state.animation_pixels, animation_id)
    formatted_animations = build_formatted_animations(animations_map, animation_pixels)

    {:noreply,
     schedule_snapshot(%{
       state
       | animations_map: animations_map,
         animation_pixels: animation_pixels,
         formatted_animations: formatted_animations
     })}
  end

  ## Private

  defp snapshot_bookkeeping do
    %{snapshot_timer: nil, build_seq: 0, last_inserted_seq: 0}
  end

  defp schedule_snapshot(state, delay \\ @snapshot_debounce)

  defp schedule_snapshot(%{snapshot_timer: nil} = state, delay) do
    %{state | snapshot_timer: Process.send_after(self(), :build_snapshot, delay)}
  end

  defp schedule_snapshot(state, _delay), do: state

  defp build_snapshot_now(state) do
    if state.snapshot_timer, do: Process.cancel_timer(state.snapshot_timer)
    seq = state.build_seq + 1

    publish_snapshot(Snapshot.build(state.formatted_pixels, state.formatted_animations))

    %{state | snapshot_timer: nil, build_seq: seq, last_inserted_seq: seq}
  end

  defp publish_snapshot(png) do
    hash = :crypto.hash(:sha256, png) |> Base.encode16(case: :lower) |> binary_part(0, 16)
    :ets.insert(@snapshot_table, {:current, hash, png})
  end

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
