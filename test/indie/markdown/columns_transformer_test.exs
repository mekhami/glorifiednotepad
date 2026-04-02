defmodule Indie.Markdown.ColumnsTransformerTest do
  use ExUnit.Case, async: true

  alias Indie.Markdown.ColumnsTransformer

  describe "transform/1" do
    test "replaces a columns block with two-column HTML" do
      markdown = """
      :::columns
      Left side text.
      ===
      Right side text.
      :::
      """

      result = ColumnsTransformer.transform(markdown)

      assert result =~ ~r/<div class="columns">/
      assert result =~ ~r/<div class="col">/
      assert result =~ "Left side text."
      assert result =~ "Right side text."
      refute result =~ ":::columns"
      refute result =~ ":::"
    end

    test "each column renders full markdown (bold, italic, links)" do
      markdown = """
      :::columns
      **Bold** and _italic_
      ===
      [a link](https://example.com)
      :::
      """

      result = ColumnsTransformer.transform(markdown)

      assert result =~ "<strong>Bold</strong>"
      assert result =~ "<em>italic</em>"
      assert result =~ ~r|<a href="https://example.com"|
    end

    test "each column renders highlight syntax" do
      markdown = """
      :::columns
      ==yellow:highlighted==
      ===
      plain
      :::
      """

      result = ColumnsTransformer.transform(markdown)

      assert result =~ ~r/<mark class="hl-yellow">/
    end

    test "multi-paragraph content in each column" do
      markdown = """
      :::columns
      First paragraph.

      Second paragraph.
      ===
      Only one paragraph.
      :::
      """

      result = ColumnsTransformer.transform(markdown)

      assert result =~ "First paragraph."
      assert result =~ "Second paragraph."
      assert result =~ "Only one paragraph."
    end

    test "multiple columns blocks in one document" do
      markdown = """
      :::columns
      Left A
      ===
      Right A
      :::

      Some text between.

      :::columns
      Left B
      ===
      Right B
      :::
      """

      result = ColumnsTransformer.transform(markdown)

      assert result =~ "Left A"
      assert result =~ "Right A"
      assert result =~ "Left B"
      assert result =~ "Right B"
      assert result =~ "Some text between."
    end

    test "columns block with no === separator passes through unchanged" do
      markdown = """
      :::columns
      No separator here.
      :::
      """

      result = ColumnsTransformer.transform(markdown)

      assert result =~ ":::columns"
      assert result =~ ":::"
    end

    test "markdown outside columns blocks is unchanged" do
      markdown = """
      # A heading

      Some intro text.

      :::columns
      Left
      ===
      Right
      :::

      Outro text.
      """

      result = ColumnsTransformer.transform(markdown)

      assert result =~ "# A heading"
      assert result =~ "Some intro text."
      assert result =~ "Outro text."
    end

    test "markdown with no columns blocks is returned unchanged" do
      markdown = "Just a normal paragraph with **bold**."
      assert ColumnsTransformer.transform(markdown) == markdown
    end
  end
end
