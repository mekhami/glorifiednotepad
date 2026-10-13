defmodule Indie.Doodle.LogoSchedulerTest do
  use ExUnit.Case, async: true

  alias Indie.Doodle.LogoScheduler

  describe "ms_until_next/2" do
    test "later the same day when before the run time" do
      now = ~U[2026-10-13 04:00:00Z]
      assert LogoScheduler.ms_until_next(now, ~T[06:00:00]) == :timer.hours(2)
    end

    test "tomorrow when already past the run time" do
      now = ~U[2026-10-13 06:00:01Z]
      assert LogoScheduler.ms_until_next(now, ~T[06:00:00]) == :timer.hours(24) - 1_000
    end

    test "tomorrow when exactly at the run time" do
      now = ~U[2026-10-13 06:00:00Z]
      assert LogoScheduler.ms_until_next(now, ~T[06:00:00]) == :timer.hours(24)
    end
  end
end
