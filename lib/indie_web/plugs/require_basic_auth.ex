defmodule IndieWeb.Plugs.RequireBasicAuth do
  @moduledoc """
  Plug for HTTP Basic Authentication using environment variables.

  Requires ADMIN_USERNAME and ADMIN_PASSWORD environment variables to be set.
  """

  def init(opts), do: opts

  def call(conn, _opts) do
    username = get_env_var("ADMIN_USERNAME")
    password = get_env_var("ADMIN_PASSWORD")

    Plug.BasicAuth.basic_auth(conn, username: username, password: password, realm: "Admin")
  end

  defp get_env_var(key) do
    case System.get_env(key) do
      nil ->
        raise """
        Environment variable #{key} is not set.

        Please set it in your environment or .env file:
        export #{key}="your-value"
        """

      value ->
        value
    end
  end
end
