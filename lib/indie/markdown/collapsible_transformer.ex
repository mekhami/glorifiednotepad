defmodule Indie.Markdown.CollapsibleTransformer do
  @moduledoc """
  Pre-processor that transforms [collapsed Title]...[/collapsed] blocks into
  <details>/<summary> HTML, with the inner content rendered as markdown.

  Syntax:
      [collapsed Title of section]
      Paragraph content here.

      More paragraphs, **bold**, _italic_, etc.
      [/collapsed]

  Output:
      <details>
      <summary>Title of section</summary>
      <div class="details-body">
      <p>Paragraph content here.</p>
      ...
      </div>
      </details>

  The title text is optional — [collapsed] with no title renders with just the
  arrow indicator from CSS.
  """

  @pattern ~r/\[collapsed([^\]]*)\]\n(.*?)\n?\[\/collapsed\]/s

  @doc """
  Scans `markdown` for [collapsed ...]...[/collapsed] blocks, renders the inner
  content as markdown, and replaces each block with a <details> HTML structure.
  Returns the modified markdown string.
  """
  @spec transform(String.t()) :: String.t()
  def transform(markdown) do
    Regex.replace(@pattern, markdown, fn _full, title_raw, body_raw ->
      title = String.trim(title_raw)
      inner_html = body_raw |> String.trim() |> Earmark.as_html!(breaks: true) |> String.trim()

      """
      <details>
      <summary>#{title}</summary>
      <div class="details-body">
      #{inner_html}
      </div>
      </details>
      """
      |> String.trim_trailing()
    end)
  end
end
