defmodule IndieWeb.Admin.StonetopSessionsAdminLive do
  use IndieWeb, :live_view

  alias Indie.Stonetop
  alias Indie.Stonetop.Session

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Stonetop Sessions")
     |> assign(:sessions, Stonetop.list_sessions())
     |> assign(:editing, nil)
     |> assign(:form, nil)}
  end

  @impl true
  def handle_params(%{"id" => "new"}, _uri, socket) do
    session = %Session{number: Stonetop.next_session_number(), played_on: Date.utc_today()}
    {:noreply, edit(socket, session)}
  end

  def handle_params(%{"id" => id}, _uri, socket) do
    case Stonetop.get_session(id) do
      nil -> {:noreply, push_patch(socket, to: ~p"/admin/stonetop/sessions")}
      session -> {:noreply, edit(socket, session)}
    end
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket |> assign(:editing, nil) |> assign(:form, nil)}
  end

  @impl true
  def handle_event("validate", %{"session" => params}, socket) do
    form =
      socket.assigns.editing
      |> Stonetop.change_session(params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", %{"session" => params}, socket) do
    result =
      case socket.assigns.editing do
        %Session{id: nil} -> Stonetop.create_session(params)
        session -> Stonetop.update_session(session, params)
      end

    case result do
      {:ok, session} ->
        {:noreply,
         socket
         |> put_flash(:info, "Session #{session.number} saved")
         |> assign(:sessions, Stonetop.list_sessions())
         |> push_patch(to: ~p"/admin/stonetop/sessions")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  def handle_event("delete", _, socket) do
    {:ok, _} = Stonetop.delete_session(socket.assigns.editing)

    {:noreply,
     socket
     |> put_flash(:info, "Session deleted")
     |> assign(:sessions, Stonetop.list_sessions())
     |> push_patch(to: ~p"/admin/stonetop/sessions")}
  end

  defp edit(socket, session) do
    socket
    |> assign(:editing, session)
    |> assign(:form, to_form(Stonetop.change_session(session)))
  end
end
