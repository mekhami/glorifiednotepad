defmodule IndieWeb.MarkdownHelpers do
  @moduledoc """
  Helper functions for rendering markdown content safely.
  """

  @doc """
  Renders markdown content from a comment body into safe HTML.

  Supports basic markdown features:
  - Links: [text](url)
  - Bold: **text** or __text__
  - Italic: *text* or _text_
  - Inline code: `code`
  - Line breaks

  The output is sanitized to prevent XSS attacks by only allowing
  markdown-generated HTML tags.

  ## Examples

      iex> render_comment_markdown("Check out [this link](https://example.com)")
      ~s(<p>Check out <a href="https://example.com">this link</a></p>)

  """
  def render_comment_markdown(body) when is_binary(body) do
    body
    |> Earmark.as_html!(breaks: true, escape: true)
    |> String.trim()
  end

  def render_comment_markdown(_), do: ""
end
