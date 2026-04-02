defmodule Indie.Markdown.ColumnsTransformer do
  @moduledoc """
  Pre-processor that transforms :::columns ... ::: fenced blocks in markdown
  into two-column HTML. Each column's content is rendered through the full
  Earmark + HighlightTransformer pipeline, so bold, italic, links, lists,
  and ==highlight== syntax all work inside columns.

  Syntax:
      :::columns
      Left column markdown content
      ===
      Right column markdown content
      :::

  Blocks without a === separator are passed through unchanged.

  ## Earmark passthrough note

  The injected HTML uses newline-separated block-level divs so that Earmark
  treats the outer `<div>` as a verbatim HTML block and does not re-process
  the content. The opening tag must be on its own line — Earmark hangs if
  the opening tag is on the same line as inner content with unclosed tags.
  """

  @columns_pattern ~r/:::columns\n(.*?)\n===\n(.*?)\n:::/s

  @doc """
  Scans `markdown` for :::columns blocks and replaces each with rendered HTML.
  Returns the modified markdown string.
  """
  @spec transform(String.t()) :: String.t()
  def transform(markdown) do
    Regex.replace(@columns_pattern, markdown, fn _full, left, right ->
      left_html = render_column(left)
      right_html = render_column(right)

      ~s(<div class="columns">\n<div class="col">#{left_html}</div>\n<div class="col">#{right_html}</div>\n</div>)
    end)
  end

  defp render_column(markdown) do
    markdown
    |> Earmark.as_ast!(breaks: true)
    |> Indie.Markdown.HighlightTransformer.transform()
    |> Earmark.Transform.transform()
  end
end
