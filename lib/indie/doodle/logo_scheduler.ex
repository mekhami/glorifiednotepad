defmodule Indie.Doodle.LogoScheduler do
  @moduledoc """
  Repaints the canvas logo (`Indie.Doodle.SeedLogo`) once a day at a fixed UTC time.

  Configure with:

      config :indie, Indie.Doodle.LogoScheduler, enabled: true, at: ~T[06:00:00]
  """
  use GenServer

  require Logger

  @default_at ~T[06:00:00]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Milliseconds from `now` until the next occurrence of `at` (UTC). Never zero."
  def ms_until_next(%DateTime{} = now, %Time{} = at) do
    today = DateTime.new!(DateTime.to_date(now), at, "Etc/UTC")

    next =
      if DateTime.compare(today, now) == :gt,
        do: today,
        else: DateTime.add(today, 1, :day)

    DateTime.diff(next, now, :millisecond)
  end

  @impl true
  def init(_opts) do
    config = Application.get_env(:indie, __MODULE__, [])

    if Keyword.get(config, :enabled, true) do
      at = Keyword.get(config, :at, @default_at)
      {:ok, schedule(%{at: at})}
    else
      :ignore
    end
  end

  @impl true
  def handle_info(:seed, state) do
    try do
      Indie.Doodle.SeedLogo.run()
    rescue
      e -> Logger.error("LogoScheduler: seed failed: " <> Exception.message(e))
    end

    {:noreply, schedule(state)}
  end

  defp schedule(%{at: at} = state) do
    ms = ms_until_next(DateTime.utc_now(), at)
    Process.send_after(self(), :seed, ms)
    Logger.info("LogoScheduler: next logo repaint in #{div(ms, 60_000)} min")
    state
  end
end
