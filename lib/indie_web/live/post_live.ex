defmodule IndieWeb.PostLive do
  use IndieWeb, :live_view

  alias Indie.{Post, Comments, Comment}

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    # Subscribe to pixel updates when connected
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Indie.PubSub, "doodle:pixels")
    end

    case Post.get_by_id(slug) do
      nil ->
        {:ok,
         socket
         |> assign(:post_not_found, true)
         |> assign(:post, nil)
         |> assign(:comments, [])
         |> assign(:modal_open, false)
         |> assign(:comment_form, to_form(Comment.changeset(%Comment{}, %{}), as: :comment))}

      post ->
        # Load comments for this post
        comments = Comments.list_comments_for_post(post.id)

        socket =
          socket
          |> assign(:post_not_found, false)
          |> assign(:post, post)
          |> assign(:comments, comments)
          |> assign(:modal_open, false)
          |> assign(:comment_form, to_form(Comment.changeset(%Comment{}, %{}), as: :comment))

        {:ok, socket}
    end
  end

  @impl true
  def handle_event("open_comment_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:modal_open, true)
     |> assign(
       :comment_form,
       to_form(Comment.changeset(%Comment{}, %{"post_id" => socket.assigns.post.id}),
         as: :comment
       )
     )}
  end

  @impl true
  def handle_event("close_comment_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:modal_open, false)
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
        updated_comments = [comment | socket.assigns.comments] |> Enum.sort_by(& &1.inserted_at)

        {:noreply,
         socket
         |> assign(:comments, updated_comments)
         |> assign(:modal_open, false)
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
