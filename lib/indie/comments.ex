defmodule Indie.Comments do
  @moduledoc """
  Context for managing comments.
  """

  import Ecto.Query
  alias Indie.Repo
  alias Indie.Comment

  @doc """
  Returns the list of comments for a specific post, ordered oldest first.
  """
  def list_comments_for_post(post_id) do
    Comment
    |> where([c], c.post_id == ^post_id)
    |> order_by([c], asc: c.inserted_at)
    |> Repo.all()
  end

  @doc """
  Returns comments for multiple posts in one query, grouped by post_id.
  Replaces N per-post queries with a single `WHERE post_id IN (...)`.
  Returns a map of `%{post_id => [comment, ...]}`.
  """
  def list_comments_for_posts(post_ids) when is_list(post_ids) do
    Comment
    |> where([c], c.post_id in ^post_ids)
    |> order_by([c], asc: c.inserted_at)
    |> Repo.all()
    |> Enum.group_by(& &1.post_id)
  end

  @doc """
  Creates a comment.
  """
  def create_comment(attrs \\ %{}) do
    %Comment{}
    |> Comment.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a single comment by ID.
  Raises `Ecto.NoResultsError` if the Comment does not exist.
  """
  def get_comment!(id), do: Repo.get!(Comment, id)

  @doc """
  Gets a single comment by ID.
  Returns nil if the Comment does not exist.
  """
  def get_comment(id), do: Repo.get(Comment, id)

  @doc """
  Deletes a comment.
  """
  def delete_comment(%Comment{} = comment) do
    Repo.delete(comment)
  end

  @doc """
  Lists all comments across all posts.
  """
  def list_all_comments do
    Comment
    |> order_by([c], desc: c.inserted_at)
    |> Repo.all()
  end
end
