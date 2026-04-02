defmodule Indie.Markdown.HighlightTransformer do
  @moduledoc """
  Earmark AST transformer that converts ==color:text== syntax into
  <mark class="hl-color"> tags. The visual styling (gradient background,
  SVG filter for wobbly edges) is handled entirely by CSS pseudo-elements,
  keeping the text itself unaffected by the filter.
  """

  @colors ~w[yellow green blue red]

  @highlight_pattern ~r/==(\w+):(.+?)==/

  # Tags whose string children should never be transformed.
  @skip_tags ["code", "pre"]

  @doc """
  Transforms an Earmark AST, replacing ==color:text== syntax with <mark> nodes.
  Code spans and code blocks are left untouched.
  """
  @spec transform(list()) :: list()
  def transform(ast) do
    Enum.map(ast, &transform_node/1)
  end

  defp transform_node({tag, attrs, children, meta}) when tag in @skip_tags do
    {tag, attrs, children, meta}
  end

  defp transform_node({tag, attrs, children, meta}) do
    new_children =
      Enum.flat_map(children, fn
        text when is_binary(text) -> transform_text(text)
        child -> [transform_node(child)]
      end)

    {tag, attrs, new_children, meta}
  end

  defp transform_node(other), do: other

  defp transform_text(text) do
    case Regex.scan(@highlight_pattern, text, return: :index) do
      [] ->
        [text]

      matches ->
        split_text_with_highlights(text, matches)
    end
  end

  defp split_text_with_highlights(text, matches) do
    {result, last_end} =
      Enum.reduce(matches, {[], 0}, fn [{start, len} | _], {acc, cursor} ->
        segment = binary_part(text, start, len)
        [_, color, content] = Regex.run(@highlight_pattern, segment)

        prefix = binary_part(text, cursor, start - cursor)
        node = build_mark(color, content)

        new_acc =
          case prefix do
            "" -> acc ++ [node]
            _ -> acc ++ [prefix, node]
          end

        {new_acc, start + len}
      end)

    suffix = binary_part(text, last_end, byte_size(text) - last_end)

    case suffix do
      "" -> result
      _ -> result ++ [suffix]
    end
  end

  defp build_mark(color, content) do
    if color in @colors do
      {"mark", [{"class", "hl-#{color}"}], [content], %{}}
    else
      "==#{color}:#{content}=="
    end
  end
end
