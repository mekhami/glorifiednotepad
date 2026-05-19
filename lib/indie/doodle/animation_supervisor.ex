defmodule Indie.Doodle.AnimationSupervisor do
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_animation(animation) do
    case DynamicSupervisor.start_child(__MODULE__, {Indie.Doodle.AnimationServer, animation}) do
      {:ok, _pid} = result ->
        result

      {:error, {:already_started, pid}} ->
        send(pid, :reload_pixels)
        {:ok, pid}

      error ->
        error
    end
  end

  def stop_animation(animation_id) do
    case Registry.lookup(Indie.Doodle.AnimationRegistry, animation_id) do
      [{pid, _}] -> DynamicSupervisor.terminate_child(__MODULE__, pid)
      [] -> :ok
    end
  end
end
