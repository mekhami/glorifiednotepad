defmodule Indie.PostCache do
  @moduledoc """
  GenServer cache for parsed blog posts.

  Loads and parses all markdown posts once on startup, then serves them
  from memory. Parsing 24 posts through the full Earmark pipeline takes
  ~300ms per request — this reduces that to O(1).

  Call reload/0 after adding or editing content files (or just restart
  the server, since posts are static in production).
  """
  use GenServer

  alias Indie.Post

  ## Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @doc "Returns all posts sorted by date descending."
  def all do
    GenServer.call(__MODULE__, :all)
  end

  @doc "Returns all published (non-draft) posts sorted by date descending."
  def published do
    GenServer.call(__MODULE__, :published)
  end

  @doc "Reloads all posts from disk. Use after editing content in dev."
  def reload do
    GenServer.call(__MODULE__, :reload)
  end

  ## Server Callbacks

  @impl true
  def init(_) do
    {:ok, load_state()}
  end

  @impl true
  def handle_call(:all, _from, state) do
    {:reply, state.all, state}
  end

  @impl true
  def handle_call(:published, _from, state) do
    {:reply, state.published, state}
  end

  @impl true
  def handle_call(:reload, _from, _state) do
    {:reply, :ok, load_state()}
  end

  ## Private

  defp load_state do
    all = Post.load_all()
    published = Enum.reject(all, & &1.draft)
    %{all: all, published: published}
  end
end
