defmodule IndieWeb.Plugs.RequireBasicAuthTest do
  use IndieWeb.ConnCase, async: true

  alias IndieWeb.Plugs.RequireBasicAuth

  describe "call/2" do
    test "returns 401 when no credentials provided", %{conn: conn} do
      conn = RequireBasicAuth.call(conn, [])

      assert conn.status == 401
      assert conn.halted == true
      assert get_resp_header(conn, "www-authenticate") == ["Basic realm=\"Admin\""]
    end

    test "allows request through with valid credentials", %{conn: conn} do
      # Set environment variables for test
      System.put_env("ADMIN_USERNAME", "testadmin")
      System.put_env("ADMIN_PASSWORD", "testpass")

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
      System.put_env("ADMIN_USERNAME", "testadmin")
      System.put_env("ADMIN_PASSWORD", "testpass")

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
end
