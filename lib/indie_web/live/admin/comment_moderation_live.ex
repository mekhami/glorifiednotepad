defmodule IndieWeb.Admin.CommentModerationLive do
  use IndieWeb, :live_view

  alias Indie.Comments

  @impl true
  def mount(_params, _session, socket) do
    all_comments = Comments.list_all_comments()
    post_ids = all_comments |> Enum.map(& &1.post_id) |> Enum.uniq()
    comment_counts = Enum.frequencies_by(all_comments, & &1.post_id)

    socket =
      socket
      |> assign(:all_comments, all_comments)
      |> assign(:filtered_comments, all_comments)
      |> assign(:selected_post_id, nil)
      |> assign(:post_ids, post_ids)
      |> assign(:comment_counts, comment_counts)

    {:ok, socket}
  end

  @impl true
  def handle_event("filter_by_post", %{"post_id" => ""}, socket) do
    # Empty string means "All Posts"
    socket =
      socket
      |> assign(:selected_post_id, nil)
      |> assign(:filtered_comments, socket.assigns.all_comments)

    {:noreply, socket}
  end

  def handle_event("filter_by_post", %{"post_id" => post_id}, socket) do
    filtered = Enum.filter(socket.assigns.all_comments, &(&1.post_id == post_id))

    socket =
      socket
      |> assign(:selected_post_id, post_id)
      |> assign(:filtered_comments, filtered)

    {:noreply, socket}
  end

  @impl true
  def handle_event("delete_comment", %{"id" => id}, socket) do
    comment_id = String.to_integer(id)
    comment = Comments.get_comment!(comment_id)

    case Comments.delete_comment(comment) do
      {:ok, _deleted_comment} ->
        # Remove from all_comments
        updated_all_comments = Enum.reject(socket.assigns.all_comments, &(&1.id == comment_id))

        # Recalculate derived data
        post_ids = updated_all_comments |> Enum.map(& &1.post_id) |> Enum.uniq()
        comment_counts = Enum.frequencies_by(updated_all_comments, & &1.post_id)

        # Reapply current filter
        filtered =
          case socket.assigns.selected_post_id do
            nil -> updated_all_comments
            post_id -> Enum.filter(updated_all_comments, &(&1.post_id == post_id))
          end

        socket =
          socket
          |> assign(:all_comments, updated_all_comments)
          |> assign(:filtered_comments, filtered)
          |> assign(:post_ids, post_ids)
          |> assign(:comment_counts, comment_counts)
          |> put_flash(:info, "Comment deleted successfully")

        {:noreply, socket}

      {:error, _reason} ->
        socket = put_flash(socket, :error, "Failed to delete comment")
        {:noreply, socket}
    end
  end

  defp format_timestamp(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y at %I:%M %p")
  end
end
