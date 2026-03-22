defmodule IndieWeb.Plugs.RequireBasicAuthTest do
  use IndieWeb.ConnCase, async: false

  alias IndieWeb.Plugs.RequireBasicAuth

  setup do
    old_username = System.get_env("ADMIN_USERNAME")
    old_password = System.get_env("ADMIN_PASSWORD")

    System.put_env("ADMIN_USERNAME", "testadmin")
    System.put_env("ADMIN_PASSWORD", "testpass")

    on_exit(fn ->
      restore_env("ADMIN_USERNAME", old_username)
      restore_env("ADMIN_PASSWORD", old_password)
    end)

    :ok
  end

  describe "call/2" do
    test "returns 401 when no credentials provided", %{conn: conn} do
      conn = RequireBasicAuth.call(conn, [])

      assert conn.status == 401
      assert conn.halted == true
      assert get_resp_header(conn, "www-authenticate") == ["Basic realm=\"Admin\""]
    end

    test "allows request through with valid credentials", %{conn: conn} do
      # Encode credentials
      credentials = Base.encode64("testadmin:testpass")

      conn =
        conn
        |> put_req_header("authorization", "Basic #{credentials}")
        |> RequireBasicAuth.call([])

      refute conn.halted
      assert conn.status != 401
    end

    test "returns 401 with invalid credentials", %{conn: conn} do
      # Wrong password
      credentials = Base.encode64("testadmin:wrongpassword")

      conn =
        conn
        |> put_req_header("authorization", "Basic #{credentials}")
        |> RequireBasicAuth.call([])

      assert conn.status == 401
      assert conn.halted == true
    end
  end

  defp restore_env(_key, nil), do: :ok
  defp restore_env(key, value), do: System.put_env(key, value)
end
