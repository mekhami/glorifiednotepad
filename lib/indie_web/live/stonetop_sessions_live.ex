defmodule IndieWeb.StonetopSessionsLive do
  use IndieWeb, :live_view

  import IndieWeb.MarkdownHelpers

  alias Indie.Stonetop

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Session Notes")
     |> assign(:sessions, Stonetop.list_sessions())
     |> assign(:current, nil)}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    case Stonetop.get_session_by_slug(id) do
      nil ->
        {:noreply, assign(socket, :current, nil)}

      session ->
        {:noreply,
         socket
         |> assign(:current, session)
         |> assign(:page_title, session_label(session))}
    end
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, :current, List.first(socket.assigns.sessions))}
  end

  def session_label(%{title: title, number: n}) when title in [nil, ""], do: "Session #{n}"
  def session_label(%{title: title, number: n}), do: "Session #{n}: #{title}"

  def format_date(nil), do: nil
  def format_date(date), do: Calendar.strftime(date, "%-d %B %Y")

  # Sessions are listed newest first, so the "earlier" session is the next one.
  defp neighbours(sessions, current) do
    idx = Enum.find_index(sessions, &(&1.id == current.id))
    later = if idx > 0, do: Enum.at(sessions, idx - 1)
    {Enum.at(sessions, idx + 1), later}
  end
end
