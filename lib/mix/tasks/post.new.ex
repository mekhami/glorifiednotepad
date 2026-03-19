defmodule Mix.Tasks.Post.New do
  use Mix.Task

  @shortdoc "Creates a new post"

  @moduledoc """
  Creates a new post with frontmatter.

  ## Usage

      mix post.new
  """

  def run(_args) do
    # 1. Prompt for title
    title =
      IO.gets("Title of the post? ")
      |> String.trim()

    if title == "" do
      Mix.raise("Title cannot be empty")
    end

    # 2. Generate slug and filename
    slug = slugify(title)
    filename = "content/#{slug}.md"

    if File.exists?(filename) do
      Mix.raise("File #{filename} already exists")
    end

    # 3. Prompt for width
    width_input =
      IO.gets("Width? [60%] ")
      |> String.trim()

    width = if width_input == "", do: "60%", else: width_input

    # 4. Generate content
    date = Date.utc_today()

    content = """
    ---
    title: "#{title}"
    id: "#{slug}"
    date: #{date}
    width: #{width}
    draft: true
    ---

    Post coming soon...
    """

    # 5. Write file
    File.write!(filename, content)

    Mix.shell().info([:green, "* created ", :reset, filename])
  end

  defp slugify(title) do
    title
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.replace(~r/\s+/, "-")
  end
end
