defmodule IndieWeb.Admin.AdminLive do
  @moduledoc false

  import Phoenix.Component

  def on_mount(:admin, _params, _session, socket) do
    {:cont, assign(socket, :current_scope, %{admin: true})}
  end
end
