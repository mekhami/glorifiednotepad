defmodule IndieWeb.HomeLive do
  use IndieWeb, :live_view

  alias Indie.{Post, Comments, Comment}

  @impl true
  def mount(_params, _session, socket) do
    # Subscribe to pixel updates when connected
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Indie.PubSub, "doodle:pixels")
    end

    all_posts = Post.published()
    posts_to_show = Enum.take(all_posts, 10)
    has_more = length(all_posts) > 10

    # Add pixel colors to each post
    posts_with_pixels = add_pixel_colors_to_posts(posts_to_show)

    # Load comments for all posts
    comments_by_post =
      posts_to_show
      |> Enum.map(fn post ->
        {post.id, Comments.list_comments_for_post(post.id)}
      end)
      |> Map.new()

    socket =
      socket
      |> assign(:posts, posts_with_pixels)
      |> assign(:all_posts, all_posts)
      |> assign(:posts_shown, 10)
      |> assign(:has_more, has_more)
      |> assign(:comments_by_post, comments_by_post)
      |> assign(:modal_open_for_post, nil)
      |> assign(:image_modal_src, nil)
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

    new_comments =
      new_posts
      |> Enum.map(fn post ->
        {post.id, Comments.list_comments_for_post(post.id)}
      end)
      |> Map.new()

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
  def handle_event("open_image_modal", %{"src" => src}, socket) do
    {:noreply, assign(socket, :image_modal_src, src)}
  end

  @impl true
  def handle_event("close_image_modal", _, socket) do
    {:noreply, assign(socket, :image_modal_src, nil)}
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

  defp add_pixel_colors_to_posts(posts) do
    Enum.map(posts, fn post ->
      Map.put(post, :pixel_colors, generate_pixel_colors(post.id))
    end)
  end

  # Generate deterministic pixel colors based on post ID
  @doc false
  def generate_pixel_colors(post_id, count \\ 18)

  def generate_pixel_colors(_post_id, 0), do: []

  def generate_pixel_colors(post_id, count) do
    seed = :erlang.phash2(post_id)

    # :exsss algorithm expects a 3-tuple seed
    rand_state = :rand.seed_s(:exsss, {seed, seed, seed})

    # Color palette matching rootring widget aesthetic
    colors = [
      "#FF00FF",
      "#00FFFF",
      "#FFFF00",
      "#FF6B6B",
      "#4ECDC4",
      "#95E1D3",
      "#F38181",
      "#AA96DA",
      "#FCBAD3",
      "#FFFFD2",
      "#A8E6CF",
      "#FFD3B6",
      "#FFAAA5",
      "#FF8B94",
      "#6C5CE7",
      "#FD79A8",
      "#FDCB6E",
      "#00B894"
    ]

    # Generate pixel colors using isolated state
    {pixel_colors, _final_state} =
      Enum.map_reduce(1..count, rand_state, fn _, state ->
        {random_idx, new_state} = :rand.uniform_s(length(colors), state)
        {Enum.at(colors, random_idx - 1), new_state}
      end)

    pixel_colors
  end
end
