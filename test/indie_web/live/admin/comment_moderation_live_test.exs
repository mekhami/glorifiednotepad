defmodule IndieWeb.Admin.CommentModerationLiveTest do
  use IndieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  alias Indie.Comments
  alias Indie.Repo
  alias Indie.Comment

  setup do
    # Set test credentials
    System.put_env("ADMIN_USERNAME", "testadmin")
    System.put_env("ADMIN_PASSWORD", "testpass")
    :ok
  end

  describe "mount" do
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

      # Add auth header
      credentials = Base.encode64("testadmin:testpass")
      conn = put_req_header(conn, "authorization", "Basic #{credentials}")

      {:ok, view, _html} = live(conn, "/admin/comments")

      # Verify assigns
      assert view |> element("#post-filter") |> has_element?()
      assert view |> has_element?("div", "Great post!")
      assert view |> has_element?("div", "Interesting read.")
    end
  end

  describe "filter_by_post" do
    test "filters comments by selected post", %{conn: conn} do
      {:ok, _comment1} =
        Comments.create_comment(%{
          post_id: "post-a",
          author_name: "Alice",
          body: "Comment on post A"
        })

      {:ok, _comment2} =
        Comments.create_comment(%{
          post_id: "post-b",
          author_name: "Bob",
          body: "Comment on post B"
        })

      credentials = Base.encode64("testadmin:testpass")
      conn = put_req_header(conn, "authorization", "Basic #{credentials}")

      {:ok, view, _html} = live(conn, "/admin/comments")

      # Select post-a from dropdown
      view
      |> element("#post-filter")
      |> render_change(%{"post_id" => "post-a"})

      # Should show only post-a comment
      assert view |> has_element?("div", "Comment on post A")
      refute view |> has_element?("div", "Comment on post B")
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

      credentials = Base.encode64("testadmin:testpass")
      conn = put_req_header(conn, "authorization", "Basic #{credentials}")

      {:ok, view, _html} = live(conn, "/admin/comments")

      # Verify comment exists
      assert view |> has_element?("div", "To be deleted")

      # Delete the comment
      view
      |> element("button[phx-click='delete_comment'][phx-value-id='#{comment.id}']")
      |> render_click()

      # Verify comment is gone from UI
      refute view |> has_element?("div", "To be deleted")

      # Verify comment is deleted from database (use Repo.get instead of get_comment!)
      assert Repo.get(Comment, comment.id) == nil
    end
  end
end
