defmodule IndieWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  require Logger

  @tracked_views [IndieWeb.HomeLive, IndieWeb.PostLive]
  @tracked_components [IndieWeb.DoodleCanvasComponent]

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    :telemetry.attach_many(
      "indie-liveview-perf",
      [
        [:phoenix, :live_view, :mount, :stop],
        [:phoenix, :live_view, :render, :stop],
        [:phoenix, :live_component, :update, :stop]
      ],
      &__MODULE__.handle_event/4,
      nil
    )

    children = [
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def handle_event([:phoenix, :live_view, :mount, :stop], measurements, metadata, _config) do
    view = metadata.socket.view

    if view in @tracked_views do
      ms = System.convert_time_unit(measurements.duration, :native, :millisecond)
      Logger.info("[LV Perf] #{inspect(view)} mount #{ms}ms")
    end
  end

  def handle_event([:phoenix, :live_view, :render, :stop], measurements, metadata, _config) do
    view = metadata.socket.view

    if view in @tracked_views do
      ms = System.convert_time_unit(measurements.duration, :native, :millisecond)
      Logger.info("[LV Perf] #{inspect(view)} render #{ms}ms")
    end
  end

  def handle_event([:phoenix, :live_component, :update, :stop], measurements, metadata, _config) do
    if metadata.component in @tracked_components do
      ms = System.convert_time_unit(measurements.duration, :native, :millisecond)
      Logger.info("[LV Perf] #{inspect(metadata.component)} update #{ms}ms")
    end
  end

  def handle_event(_event, _measurements, _metadata, _config), do: :ok

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.start.system_time",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.start.system_time",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.exception.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.socket_connected.duration",
        unit: {:native, :millisecond}
      ),
      sum("phoenix.socket_drain.count"),
      summary("phoenix.channel_joined.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.channel_handled_in.duration",
        tags: [:event],
        unit: {:native, :millisecond}
      ),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io")
    ]
  end

  defp periodic_measurements do
    [
      # A module, function and arguments to be invoked periodically.
      # This function must call :telemetry.execute/3 and a metric must be added above.
      # {IndieWeb, :count_users, []}
    ]
  end
end
