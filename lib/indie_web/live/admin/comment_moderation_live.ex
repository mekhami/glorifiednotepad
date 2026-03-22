defmodule IndieWeb.Admin.CommentModerationLive do
  use IndieWeb, :live_view

  alias Indie.Comments
  alias Indie.Comment
  alias Indie.Post
  alias Indie.Repo

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> stream_configure(:comments, dom_id: &"comment-#{&1.id}")
      |> assign_comment_data(nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("filter_by_post", %{"filter" => %{"post_id" => post_id}}, socket) do
    selected_post_id = if post_id == "", do: nil, else: post_id

    socket =
      socket
      |> assign(:confirming_comment_id, nil)
      |> assign_comment_data(selected_post_id)

    {:noreply, socket}
  end

  @impl true
  def handle_event("confirm_delete", %{"id" => id}, socket) do
    comment_id = String.to_integer(id)
    comment = Enum.find(socket.assigns.all_comments, &(&1.id == comment_id))

    socket =
      socket
      |> assign(:confirming_comment_id, comment_id)
      |> maybe_stream_insert(comment)

    {:noreply, socket}
  end

  def handle_event("delete_comment", %{"id" => id}, socket) do
    comment_id = String.to_integer(id)

    case Repo.get(Comment, comment_id) do
      nil ->
        comment = Enum.find(socket.assigns.all_comments, &(&1.id == comment_id))

        socket =
          socket
          |> assign(:confirming_comment_id, nil)
          |> maybe_stream_insert(comment)
          |> put_flash(:error, "Comment not found")

        {:noreply, socket}

      %Comment{} = comment ->
        case Comments.delete_comment(comment) do
          {:ok, _deleted_comment} ->
            socket =
              socket
              |> assign(:confirming_comment_id, nil)
              |> assign_comment_data(socket.assigns.selected_post_id)
              |> put_flash(:info, "Comment deleted successfully")

            {:noreply, socket}

          {:error, _reason} ->
            socket =
              socket
              |> assign(:confirming_comment_id, nil)
              |> assign_comment_data(socket.assigns.selected_post_id)
              |> put_flash(:error, "Failed to delete comment")

            {:noreply, socket}
        end
    end
  end

  defp format_timestamp(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y at %I:%M %p")
  end

  defp assign_comment_data(socket, selected_post_id) do
    all_comments = Comments.list_all_comments()
    post_ids = all_comments |> Enum.map(& &1.post_id) |> Enum.uniq()
    comment_counts = Enum.frequencies_by(all_comments, & &1.post_id)
    filtered_comments = filter_comments(all_comments, selected_post_id)
    total_count = length(all_comments)
    filtered_count = length(filtered_comments)
    post_titles = post_titles()

    post_options =
      post_ids
      |> Enum.map(fn post_id ->
        {Map.get(post_titles, post_id, post_id), post_id}
      end)

    socket
    |> assign(:all_comments, all_comments)
    |> assign(:filtered_comments, filtered_comments)
    |> assign(:selected_post_id, selected_post_id)
    |> assign(:confirming_comment_id, nil)
    |> assign(:post_ids, post_ids)
    |> assign(:comment_counts, comment_counts)
    |> assign(:post_options, post_options)
    |> assign(:post_titles, post_titles)
    |> assign(:total_count, total_count)
    |> assign(:filtered_count, filtered_count)
    |> assign(:filter_form, filter_form(selected_post_id))
    |> stream(:comments, filtered_comments, reset: true)
  end

  defp filter_comments(comments, nil), do: comments
  defp filter_comments(comments, post_id), do: Enum.filter(comments, &(&1.post_id == post_id))

  defp filter_form(selected_post_id) do
    to_form(%{"post_id" => selected_post_id || ""}, as: :filter)
  end

  defp post_titles do
    Post.published()
    |> Enum.map(&{&1.id, &1.title})
    |> Map.new()
  end

  defp maybe_stream_insert(socket, nil), do: socket
  defp maybe_stream_insert(socket, comment), do: stream_insert(socket, :comments, comment)
end
