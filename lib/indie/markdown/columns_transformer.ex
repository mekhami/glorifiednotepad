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

  Additionally, the rendered column HTML is compacted to remove internal
  newlines before injection. Earmark's verbatim HTML block parser processes
  line by line, so a multi-line tag like:

      <h4>
      <em>text</em></h4>

  is seen as `<h4>` (opened, no close) on one line and `...<em>...</em>...</h4>`
  on the next — generating "Failed to find closing <h4>" warnings and broken
  output. Collapsing to a single line per top-level block prevents this.
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
    |> compact_html()
  end

  # Earmark's Transform.transform/1 produces multi-line HTML for block elements
  # (e.g. <h4>\n<em>text</em></h4>). When that HTML is re-ingested as a verbatim
  # block by the outer Earmark pass, its line-by-line HTML parser sees <h4> as an
  # unclosed tag on one line, triggering "Failed to find closing <h4>" warnings.
  # Collapsing internal newlines to spaces makes every tag self-contained on its
  # own line so the outer parser can match open/close pairs correctly.
  #
  # After joining, whitespace around tag boundaries is collapsed to nothing —
  # Earmark pads inline elements with spaces (e.g. "  <mark...> word  </mark> ")
  # which renders as unwanted visible spaces around highlighted text. Stripping
  # whitespace at `>` and `<` boundaries removes this without affecting
  # word-to-word spacing in prose, since inline elements in HTML don't need
  # explicit spaces around them (the browser handles word boundaries naturally
  # from the surrounding text nodes).
  defp compact_html(html) do
    html
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(" ")
    # Collapse all multi-space runs to a single space
    |> String.replace(~r/  +/, " ")
    # Strip spaces between adjacent tags (closing > followed by opening <)
    |> String.replace(~r/> </, "><")
    # Strip spaces immediately after any opening tag (e.g. <mark> word -> <mark>word)
    |> String.replace(~r/<([a-zA-Z][^>]*)> /, "<\\1>")
    # Strip spaces immediately before any closing tag (e.g. word </mark> -> word</mark>)
    |> String.replace(~r/ <\/([a-zA-Z]+)>/, "</\\1>")
    # Strip spaces between non-word punctuation and an opening tag (e.g. ( <mark -> (<mark)
    |> String.replace(~r/([(\[{]) </, "\\1<")
    # Strip spaces between a closing tag and non-word punctuation (e.g. </mark> ) -> </mark>))
    |> String.replace(~r/> ([)\]}.,;:!?])/, ">\\1")
  end
end
