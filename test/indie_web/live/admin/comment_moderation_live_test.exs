defmodule IndieWeb.Admin.CommentModerationLiveTest do
  use IndieWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  alias Indie.Comments
  alias Indie.Repo
  alias Indie.Comment

  setup %{conn: conn} do
    old_username = System.get_env("ADMIN_USERNAME")
    old_password = System.get_env("ADMIN_PASSWORD")

    System.put_env("ADMIN_USERNAME", "testadmin")
    System.put_env("ADMIN_PASSWORD", "testpass")

    on_exit(fn ->
      restore_env("ADMIN_USERNAME", old_username)
      restore_env("ADMIN_PASSWORD", old_password)
    end)

    {:ok, conn: admin_conn(conn)}
  end

  describe "mount" do
    test "admin comments route is live", %{conn: conn} do
      assert {:ok, _view, _html} = live(conn, "/admin/comments")
    end

    test "requires basic auth" do
      conn = build_conn() |> get("/admin/comments")
      assert conn.status == 401
    end

    test "admin UI renders filter and list", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/comments")
      assert has_element?(view, "#post-filter")
      assert has_element?(view, "#filter-count")
      assert has_element?(view, "#comments")
    end

    test "loads all comments on mount", %{conn: conn} do
      # Create test comments
      {:ok, comment1} =
        Comments.create_comment(%{
          post_id: "test-post-1",
          author_name: "Alice",
          body: "Great post!"
        })

      {:ok, comment2} =
        Comments.create_comment(%{
          post_id: "test-post-2",
          author_name: "Bob",
          body: "Interesting read."
        })

      {:ok, view, _html} = live(conn, "/admin/comments")

      # Verify elements
      assert has_element?(view, "#post-filter")
      assert has_element?(view, "#comment-#{comment1.id}")
      assert has_element?(view, "#comment-#{comment2.id}")
    end
  end

  describe "filter_by_post" do
    test "filters comments by selected post", %{conn: conn} do
      {:ok, comment1} =
        Comments.create_comment(%{
          post_id: "post-a",
          author_name: "Alice",
          body: "Comment on post A"
        })

      {:ok, comment2} =
        Comments.create_comment(%{
          post_id: "post-b",
          author_name: "Bob",
          body: "Comment on post B"
        })

      {:ok, view, _html} = live(conn, "/admin/comments")

      # Select post-a from dropdown
      view
      |> element("#filter-form")
      |> render_change(%{"filter" => %{"post_id" => "post-a"}})

      # Should show only post-a comment
      assert has_element?(view, "#comment-#{comment1.id}")
      refute has_element?(view, "#comment-#{comment2.id}")
    end

    test "shows empty state when filter has no matches", %{conn: conn} do
      {:ok, comment} =
        Comments.create_comment(%{
          post_id: "post-a",
          author_name: "Alice",
          body: "Comment on post A"
        })

      {:ok, view, _html} = live(conn, "/admin/comments")

      assert has_element?(view, "#comment-#{comment.id}")

      view
      |> element("#filter-form")
      |> render_change(%{"filter" => %{"post_id" => "missing-post"}})

      assert has_element?(view, "#comments-empty")
    end

    test "resets confirm state on filter change", %{conn: conn} do
      {:ok, comment_a} =
        Comments.create_comment(%{
          post_id: "post-a",
          author_name: "Alice",
          body: "Comment on post A"
        })

      {:ok, comment_b} =
        Comments.create_comment(%{
          post_id: "post-b",
          author_name: "Bob",
          body: "Comment on post B"
        })

      {:ok, view, _html} = live(conn, "/admin/comments")

      view
      |> element("#comment-delete-#{comment_a.id}")
      |> render_click()

      assert has_element?(view, "#comment-confirm-#{comment_a.id}")

      view
      |> element("#filter-form")
      |> render_change(%{"filter" => %{"post_id" => "post-b"}})

      assert has_element?(view, "#comment-#{comment_b.id}")
      refute has_element?(view, "#comment-confirm-#{comment_a.id}")
    end
  end

  describe "delete_comment" do
    test "deletes comment and updates UI", %{conn: conn} do
      {:ok, comment} =
        Comments.create_comment(%{
          post_id: "post-x",
          author_name: "Charlie",
          body: "To be deleted"
        })

      {:ok, view, _html} = live(conn, "/admin/comments")

      # Verify comment exists
      assert has_element?(view, "#comment-#{comment.id}")

      # Delete the comment
      view
      |> element("#comment-delete-#{comment.id}")
      |> render_click()

      view
      |> element("#comment-confirm-#{comment.id}")
      |> render_click()

      # Verify comment is gone from UI
      refute has_element?(view, "#comment-#{comment.id}")
      refute has_element?(view, "#comment-confirm-#{comment.id}")
      assert has_element?(view, "#flash-info")

      # Verify comment is deleted from database (use Repo.get instead of get_comment!)
      assert Repo.get(Comment, comment.id) == nil
    end

    test "delete handles missing comment", %{conn: conn} do
      {:ok, comment} =
        Comments.create_comment(%{
          post_id: "post-x",
          author_name: "Charlie",
          body: "Temp"
        })

      {:ok, view, _html} = live(conn, "/admin/comments")

      view |> element("#comment-delete-#{comment.id}") |> render_click()
      _ = Comments.delete_comment(comment)
      view |> element("#comment-confirm-#{comment.id}") |> render_click()
      assert has_element?(view, "#flash-error")
      assert has_element?(view, "#comment-#{comment.id}")
    end
  end

  defp restore_env(_key, nil), do: :ok
  defp restore_env(key, value), do: System.put_env(key, value)

  defp admin_conn(conn) do
    credentials = Base.encode64("testadmin:testpass")
    put_req_header(conn, "authorization", "Basic #{credentials}")
  end
end
