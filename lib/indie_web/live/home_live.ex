defmodule IndieWeb.HomeLive do
  use IndieWeb, :live_view

  import IndieWeb.MarkdownHelpers

  require Logger

  alias Indie.{Post, Comments, Comment}

  @impl true
  def mount(_params, _session, socket) do
    connected = connected?(socket)

    # Subscribe to pixel updates when connected
    if connected do
      Phoenix.PubSub.subscribe(Indie.PubSub, "doodle:pixels")
    end

    t0 = System.monotonic_time(:millisecond)
    all_posts = Post.published()
    t1 = System.monotonic_time(:millisecond)

    posts_to_show = Enum.take(all_posts, 10)
    has_more = length(all_posts) > 10

    posts_with_pixels = add_pixel_colors_to_posts(posts_to_show)
    t2 = System.monotonic_time(:millisecond)

    post_ids = Enum.map(posts_to_show, & &1.id)

    comments_by_post =
      post_ids
      |> Comments.list_comments_for_posts()
      |> then(fn result -> Enum.reduce(post_ids, result, &Map.put_new(&2, &1, [])) end)

    t3 = System.monotonic_time(:millisecond)

    Logger.info(
      "[HomeLive] mount (connected=#{connected}) — " <>
        "Post.published=#{t1 - t0}ms (#{length(all_posts)} posts), " <>
        "pixel_colors=#{t2 - t1}ms, " <>
        "comments=#{t3 - t2}ms, " <>
        "total=#{t3 - t0}ms"
    )

    socket =
      socket
      |> assign(:posts, posts_with_pixels)
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

    # Add pixel colors to posts
    posts_with_pixels = add_pixel_colors_to_posts(posts_to_show)

    # Load comments for newly shown posts
    new_posts = Enum.drop(posts_to_show, socket.assigns.posts_shown)

    # Load comments for newly shown posts in one query
    new_post_ids = Enum.map(new_posts, & &1.id)

    # Ensure every new post_id has an entry (empty list for posts with no comments)
    new_comments =
      new_post_ids
      |> Comments.list_comments_for_posts()
      |> then(fn result -> Enum.reduce(new_post_ids, result, &Map.put_new(&2, &1, [])) end)

    updated_comments = Map.merge(socket.assigns.comments_by_post, new_comments)

    {:noreply,
     socket
     |> assign(:posts, posts_with_pixels)
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

  @impl true
  def handle_info({:animation_updated, animation_id, frames}, socket) do
    {:noreply,
     push_event(socket, "reload-animation", %{animation_id: animation_id, frames: frames})}
  end

  @impl true
  def handle_info({:animation_deleted, animation_id}, socket) do
    {:noreply, push_event(socket, "remove-animation", %{animation_id: animation_id})}
  end

  defp add_pixel_colors_to_posts(posts) do
    Enum.map(posts, fn post ->
      Map.put(post, :pixel_colors, IndieWeb.Pixels.generate_pixel_colors(post.id))
    end)
  end
end
