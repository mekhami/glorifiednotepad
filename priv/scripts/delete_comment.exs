#!/usr/bin/env elixir

# Usage:
#   mix run priv/scripts/delete_comment.exs --list-all
#   mix run priv/scripts/delete_comment.exs --list-post <post_id>
#   mix run priv/scripts/delete_comment.exs <comment_id>

alias Indie.{Repo, Comments, Comment}

print_usage = fn ->
  IO.puts("""

  Usage:
    mix run priv/scripts/delete_comment.exs --list-all
    mix run priv/scripts/delete_comment.exs --list-post <post_id>
    mix run priv/scripts/delete_comment.exs <comment_id>

  Examples:
    # List all comments
    mix run priv/scripts/delete_comment.exs --list-all
    
    # List comments for a specific post
    mix run priv/scripts/delete_comment.exs --list-post "the-party-is"
    
    # Delete comment with ID 42
    mix run priv/scripts/delete_comment.exs 42
  """)
end

args = System.argv()

case args do
  ["--list-all"] ->
    IO.puts("\n=== All Comments ===\n")

    comments = Comments.list_all_comments()

    if comments == [] do
      IO.puts("No comments found.")
    else
      Enum.each(comments, fn comment ->
        IO.puts("ID: #{comment.id}")
        IO.puts("Post: #{comment.post_id}")
        IO.puts("Author: #{comment.author_name}")

        IO.puts(
          "Body: #{String.slice(comment.body, 0..100)}#{if String.length(comment.body) > 100, do: "...", else: ""}"
        )

        IO.puts("Created: #{comment.inserted_at}")
        IO.puts("---")
      end)

      IO.puts("\nTotal: #{length(comments)} comment(s)")
    end

  ["--list-post", post_id] ->
    IO.puts("\n=== Comments for Post: #{post_id} ===\n")

    comments = Comments.list_comments_for_post(post_id)

    if comments == [] do
      IO.puts("No comments found for this post.")
    else
      Enum.each(comments, fn comment ->
        IO.puts("ID: #{comment.id}")
        IO.puts("Author: #{comment.author_name}")

        IO.puts(
          "Body: #{String.slice(comment.body, 0..100)}#{if String.length(comment.body) > 100, do: "...", else: ""}"
        )

        IO.puts("Created: #{comment.inserted_at}")
        IO.puts("---")
      end)

      IO.puts("\nTotal: #{length(comments)} comment(s)")
    end

  [id_str] ->
    case Integer.parse(id_str) do
      {id, ""} ->
        try do
          comment = Comments.get_comment!(id)

          IO.puts("\n=== Comment Details ===")
          IO.puts("ID: #{comment.id}")
          IO.puts("Post: #{comment.post_id}")
          IO.puts("Author: #{comment.author_name}")
          IO.puts("Body: #{comment.body}")
          IO.puts("Created: #{comment.inserted_at}")
          IO.puts("")

          response =
            IO.gets("Delete this comment? (yes/no): ") |> String.trim() |> String.downcase()

          if response in ["yes", "y"] do
            case Comments.delete_comment(comment) do
              {:ok, _} ->
                IO.puts("✓ Comment deleted successfully.")

              {:error, changeset} ->
                IO.puts("✗ Error deleting comment: #{inspect(changeset)}")
            end
          else
            IO.puts("Deletion cancelled.")
          end
        rescue
          Ecto.NoResultsError ->
            IO.puts("✗ Comment with ID #{id} not found.")
        end

      _ ->
        IO.puts("✗ Invalid comment ID: #{id_str}")
        print_usage.()
    end

  _ ->
    print_usage.()
end
