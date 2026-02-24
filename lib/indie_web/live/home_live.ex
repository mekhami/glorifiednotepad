defmodule IndieWeb.HomeLive do
  use IndieWeb, :live_view

  alias Indie.{Post, Comments, Comment}

  @impl true
  def mount(_params, _session, socket) do
    # Subscribe to pixel updates when connected
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Indie.PubSub, "doodle:pixels")
    end

    all_posts = Post.all()
    posts_to_show = Enum.take(all_posts, 10)
    has_more = length(all_posts) > 10

    # Load comments for all posts
    comments_by_post =
      posts_to_show
      |> Enum.map(fn post ->
        {post.id, Comments.list_comments_for_post(post.id)}
      end)
      |> Map.new()

    socket =
      socket
      |> assign(:posts, posts_to_show)
      |> assign(:all_posts, all_posts)
      |> assign(:posts_shown, 10)
      |> assign(:has_more, has_more)
      |> assign(:comments_by_post, comments_by_post)
      |> assign(:modal_open_for_post, nil)
      |> assign(:comment_form, to_form(Comment.changeset(%Comment{}, %{}), as: :comment))

    {:ok, socket}
  end

  @impl true
  def handle_event("open_comment_modal", %{"post-id" => post_id}, socket) do
    {:noreply,
     socket
     |> assign(:modal_open_for_post, post_id)
     |> assign(
       :comment_form,
       to_form(Comment.changeset(%Comment{}, %{"post_id" => post_id}), as: :comment)
     )}
  end

  @impl true
  def handle_event("load_more", _, socket) do
    new_count = socket.assigns.posts_shown + 10
    posts_to_show = Enum.take(socket.assigns.all_posts, new_count)
    has_more = length(socket.assigns.all_posts) > new_count

    # Load comments for newly shown posts
    new_posts = Enum.drop(posts_to_show, socket.assigns.posts_shown)

    new_comments =
      new_posts
      |> Enum.map(fn post ->
        {post.id, Comments.list_comments_for_post(post.id)}
      end)
      |> Map.new()

    updated_comments = Map.merge(socket.assigns.comments_by_post, new_comments)

    {:noreply,
     socket
     |> assign(:posts, posts_to_show)
     |> assign(:posts_shown, new_count)
     |> assign(:has_more, has_more)
     |> assign(:comments_by_post, updated_comments)}
  end

  @impl true
  def handle_event("close_comment_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:modal_open_for_post, nil)
     |> assign(:comment_form, to_form(Comment.changeset(%Comment{}, %{}), as: :comment))}
  end

  @impl true
  def handle_event("validate_comment", %{"comment" => comment_params}, socket) do
    changeset =
      %Comment{}
      |> Comment.changeset(comment_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :comment_form, to_form(changeset, as: :comment))}
  end

  @impl true
  def handle_event("submit_comment", %{"comment" => comment_params}, socket) do
    case Comments.create_comment(comment_params) do
      {:ok, comment} ->
        # Add the new comment to the local state
        post_id = comment.post_id
        updated_comments = [comment | Map.get(socket.assigns.comments_by_post, post_id, [])]

        {:noreply,
         socket
         |> update(:comments_by_post, fn comments ->
           Map.put(comments, post_id, updated_comments |> Enum.sort_by(& &1.inserted_at))
         end)
         |> assign(:modal_open_for_post, nil)
         |> assign(:comment_form, to_form(Comment.changeset(%Comment{}, %{}), as: :comment))}

      {:error, changeset} ->
        {:noreply, assign(socket, :comment_form, to_form(changeset, as: :comment))}
    end
  end

  @impl true
  def handle_info({:new_pixels, pixels}, socket) do
    # Push pixels to this client's JavaScript hook
    {:noreply, push_event(socket, "receive-pixels", %{pixels: pixels})}
  end

  @impl true
  def handle_info({:deleted_pixels, coords}, socket) do
    # Push deleted pixel coordinates to this client's JavaScript hook
    {:noreply, push_event(socket, "delete-pixels", %{coords: coords})}
  end
end
