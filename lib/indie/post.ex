defmodule Indie.Post do
  @moduledoc """
  Module for parsing and loading markdown posts with YAML front matter.
  """

  defstruct [:title, :id, :date, :html, :path, draft: false, width: "25%"]

  @content_dir "content"

  @doc """
  Loads all posts from the content directory, sorted by date (newest first).
  """
  def all do
    @content_dir
    |> content_dir_path()
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".md"))
    |> Enum.map(&load_post/1)
    |> Enum.sort_by(& &1.date, {:desc, Date})
  end

  @doc """
  Gets all published posts (excludes drafts), sorted by date (newest first).
  """
  def published do
    all()
    |> Enum.reject(& &1.draft)
  end

  @doc """
  Gets a single post by its ID. Returns nil if not found.
  Only returns published posts (excludes drafts).
  """
  def get_by_id(id) do
    published()
    |> Enum.find(&(&1.id == id))
  end

  @doc """
  Loads a single post from a filename.
  """
  def load_post(filename) do
    path = Path.join(content_dir_path(@content_dir), filename)
    content = File.read!(path)

    {front_matter, markdown} = parse_front_matter(content)

    html = Earmark.as_html!(markdown, breaks: true)

    %__MODULE__{
      title: front_matter["title"],
      id: front_matter["id"],
      date: parse_date(front_matter["date"]),
      html: html,
      path: path,
      draft: parse_boolean(front_matter["draft"]),
      width: front_matter["width"] || "25%"
    }
  end

  defp parse_front_matter(content) do
    case String.split(content, ~r/\n---\n/, parts: 2) do
      ["---\n" <> yaml, markdown] ->
        # Simple YAML parser for our basic front matter
        front_matter =
          yaml
          |> String.split("\n", trim: true)
          |> Enum.map(fn line ->
            case String.split(line, ":", parts: 2) do
              [key, value] ->
                {String.trim(key), String.trim(value) |> String.trim("\"") |> String.trim("'")}

              _ ->
                nil
            end
          end)
          |> Enum.reject(&is_nil/1)
          |> Map.new()

        {front_matter, markdown}

      _ ->
        {%{}, content}
    end
  end

  defp parse_date(date) when is_binary(date) do
    Date.from_iso8601!(date)
  end

  defp parse_date(%Date{} = date), do: date
  defp parse_date(_), do: Date.utc_today()

  defp parse_boolean("true"), do: true
  defp parse_boolean(true), do: true
  defp parse_boolean(_), do: false

  defp content_dir_path(dir) do
    # Use environment variable if set, otherwise try relative paths
    case System.get_env("CONTENT_DIR") do
      nil ->
        # In development, look for content relative to the project root
        cond do
          File.dir?("content") ->
            # Running from project root
            "content"

          File.dir?(Path.join(["..", "..", "..", dir])) ->
            # Running from _build directory
            Path.join(["..", "..", "..", dir])

          true ->
            # Fallback: use absolute path from app dir
            Path.join(Application.app_dir(:indie), "../../../#{dir}")
            |> Path.expand()
        end

      content_dir ->
        content_dir
    end
  end
end
