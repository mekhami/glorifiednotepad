defmodule Indie.Markdown.SidenotesTransformer do
  @moduledoc """
  Pre-processor that extracts sidenote definitions from markdown and replaces
  inline anchors with scoped HTML spans.

  Syntax in markdown:

      Some text with a point.[^1]

      [^1]: The sidenote text. Can use **markdown**.

  Definitions may appear anywhere in the document — before or after their anchor.
  The transformer runs before Earmark so the injected spans pass through as inline HTML.

  Returns `{transformed_markdown, sidenotes}` where `sidenotes` is a list of
  `%{number: integer, html: binary}` maps sorted by number.

  Anchor IDs are scoped to `post_id` to avoid collisions when multiple sidenote
  posts appear on the same page:

      <span class="sn-anchor" id="sn-{post_id}-{n}"><sup>n</sup></span>
  """

  # Matches: [^n]: text on a single line (anywhere in document)
  @definition_pattern ~r/^\[\^(\d+)\]:\s*(.+)$/m

  # Matches: [^n] inline anchor (not followed by :, to avoid matching definitions)
  @anchor_pattern ~r/\[\^(\d+)\](?!:)/

  @doc """
  Transforms `markdown` by extracting sidenote definitions and replacing anchors.
  `post_id` is used to scope anchor IDs (prevents collisions in multi-post views).

  Returns `{transformed_markdown, sidenotes}`.

  Anchors are injected as placeholder tokens that survive Earmark processing.
  The caller must run `replace_placeholders/1` on the final HTML string to swap
  the tokens for real `<span>` elements. `load_post/1` does this automatically
  via the post pipeline.
  """
  @spec transform(String.t(), String.t()) :: {String.t(), list(map())}
  def transform(markdown, post_id) do
    definitions =
      Regex.scan(@definition_pattern, markdown, capture: :all_but_first)
      |> Enum.map(fn [num_str, text] ->
        num = String.to_integer(num_str)
        html = render_sidenote_html(text)
        {num, html}
      end)
      |> Map.new()

    if map_size(definitions) == 0 do
      {markdown, []}
    else
      stripped =
        Regex.replace(@definition_pattern, markdown, "")
        |> String.replace(~r/\n{3,}/, "\n\n")
        |> String.trim_trailing()

      # Use placeholder tokens so Earmark does not escape the HTML.
      # Placeholders are HTML comments which Earmark passes through verbatim.
      # They are swapped to real <span> elements in replace_placeholders/2 after Earmark runs.
      with_anchors =
        Regex.replace(@anchor_pattern, stripped, fn _full, num_str ->
          num = String.to_integer(num_str)
          "<!--SN_ANCHOR_#{post_id}_#{num}-->"
        end)

      sidenotes =
        definitions
        |> Enum.sort_by(fn {num, _html} -> num end)
        |> Enum.map(fn {num, html} -> %{number: num, html: html} end)

      {with_anchors, sidenotes}
    end
  end

  @doc """
  Replaces placeholder tokens in HTML with real anchor `<span>` elements.
  Call this after the full Earmark pipeline has run.
  """
  @spec replace_placeholders(String.t(), String.t()) :: String.t()
  def replace_placeholders(html, post_id) do
    Regex.replace(~r/<!--SN_ANCHOR_#{Regex.escape(post_id)}_(\d+)-->/, html, fn _full, num_str ->
      num = String.to_integer(num_str)
      ~s(<span class="sn-anchor" id="sn-#{post_id}-#{num}"><sup>#{num}</sup></span>)
    end)
  end

  # Output is Earmark block-level HTML (e.g. wrapped in <p>...</p>).
  # CSS handles the wrapper: `.sidenote-entry p { margin: 0; }`.
  # Trailing newlines are trimmed so callers get a clean string.
  defp render_sidenote_html(text) do
    text
    |> Earmark.as_ast!(breaks: true)
    |> Earmark.Transform.transform()
    |> String.trim()
  end
end
