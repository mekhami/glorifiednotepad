defmodule Indie.Markdown.ImgTransformer do
  @moduledoc """
  Earmark AST transformer that adds loading="lazy" to all img nodes.
  Defers off-screen images so they don't compete with JS/CSS during page load.
  """

  @doc """
  Walks the Earmark AST and adds loading="lazy" to every img element.
  """
  @spec transform(list()) :: list()
  def transform(ast) do
    Enum.map(ast, &transform_node/1)
  end

  defp transform_node({"img", attrs, children, meta}) do
    attrs = add_attr(attrs, "loading", "lazy")
    {"img", attrs, children, meta}
  end

  defp transform_node({tag, attrs, children, meta}) do
    {tag, attrs, Enum.map(children, &transform_node/1), meta}
  end

  defp transform_node(other), do: other

  defp add_attr(attrs, key, value) do
    if List.keymember?(attrs, key, 0) do
      attrs
    else
      attrs ++ [{key, value}]
    end
  end
end
