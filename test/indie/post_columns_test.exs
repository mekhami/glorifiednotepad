defmodule Indie.PostColumnsTest do
  use ExUnit.Case, async: true

  @tag timeout: 5_000
  test "post with :::columns block renders without hanging" do
    body = """
    Intro paragraph.

    :::columns
    Left side with **bold** text.
    ===
    Right side with _italic_ text.
    :::

    Outro paragraph.
    """

    # Inline the pipeline from Post.load_post/1 to avoid filesystem dependency
    html =
      body
      |> Indie.Markdown.ColumnsTransformer.transform()
      |> Earmark.as_ast!(breaks: true)
      |> Indie.Markdown.HighlightTransformer.transform()
      |> Earmark.Transform.transform()

    assert html =~ ~r/<div class="columns">/
    assert html =~ "Left side"
    assert html =~ "Right side"
    assert html =~ "<strong>bold</strong>"
    assert html =~ "<em>italic</em>"
    assert html =~ "Intro paragraph."
    assert html =~ "Outro paragraph."
  end
end
