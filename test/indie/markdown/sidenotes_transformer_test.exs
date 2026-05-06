defmodule Indie.Markdown.SidenotesTransformerTest do
  use ExUnit.Case, async: true

  alias Indie.Markdown.SidenotesTransformer

  describe "transform/2" do
    test "extracts definition and returns it in sidenotes list" do
      markdown = """
      A paragraph.[^1]

      [^1]: This is the sidenote.
      """

      {_body, sidenotes} = SidenotesTransformer.transform(markdown, "my-post")

      assert length(sidenotes) == 1
      assert hd(sidenotes).number == 1
      assert hd(sidenotes).html =~ "This is the sidenote."
    end

    test "strips definition lines from returned markdown" do
      markdown = """
      A paragraph.[^1]

      [^1]: This is the sidenote.
      """

      {body, _sidenotes} = SidenotesTransformer.transform(markdown, "my-post")

      refute body =~ "[^1]:"
      refute body =~ "This is the sidenote."
    end

    test "replaces anchor marker with scoped span after replace_placeholders" do
      markdown = """
      A paragraph.[^1]

      [^1]: Note text.
      """

      {body, _sidenotes} = SidenotesTransformer.transform(markdown, "my-post")
      html = SidenotesTransformer.replace_placeholders(body, "my-post")

      assert html =~ ~r/<span class="sn-anchor" id="sn-my-post-1"><sup>1<\/sup><\/span>/
      refute html =~ "[^1]"
    end

    test "definition can appear before its anchor" do
      markdown = """
      [^1]: Note defined first.

      A paragraph.[^1]
      """

      {body, sidenotes} = SidenotesTransformer.transform(markdown, "slug")
      html = SidenotesTransformer.replace_placeholders(body, "slug")

      assert length(sidenotes) == 1
      assert html =~ ~r/sn-slug-1/
      refute body =~ "[^1]:"
    end

    test "definition can appear immediately after its paragraph" do
      markdown = """
      First paragraph.[^1]

      [^1]: First note.

      Second paragraph.[^2]

      [^2]: Second note.
      """

      {body, sidenotes} = SidenotesTransformer.transform(markdown, "the-post")
      html = SidenotesTransformer.replace_placeholders(body, "the-post")

      assert length(sidenotes) == 2
      [first, second] = sidenotes
      assert first.number == 1
      assert second.number == 2
      assert html =~ ~r/sn-the-post-1/
      assert html =~ ~r/sn-the-post-2/
    end

    test "sidenotes are sorted by number" do
      markdown = """
      [^2]: Second note.

      [^1]: First note.

      Para.[^1] Para.[^2]
      """

      {_body, sidenotes} = SidenotesTransformer.transform(markdown, "p")

      [first, second] = sidenotes
      assert first.number == 1
      assert second.number == 2
    end

    test "anchor IDs are scoped to the post_id" do
      markdown = "Text.[^1]\n\n[^1]: Note.\n"

      {body, _} = SidenotesTransformer.transform(markdown, "post-with-long-slug")
      html = SidenotesTransformer.replace_placeholders(body, "post-with-long-slug")

      assert html =~ ~s(id="sn-post-with-long-slug-1")
    end

    test "returns empty sidenotes list when no definitions present" do
      markdown = "Just a plain paragraph with no sidenotes."

      {body, sidenotes} = SidenotesTransformer.transform(markdown, "any-id")

      assert body == markdown
      assert sidenotes == []
    end

    test "sidenote html is rendered markdown (bold, links work)" do
      markdown = "Para.[^1]\n\n[^1]: **Bold** and [a link](https://example.com).\n"

      {_body, sidenotes} = SidenotesTransformer.transform(markdown, "p")

      assert hd(sidenotes).html =~ "<strong>Bold</strong>"
      assert hd(sidenotes).html =~ ~r|href="https://example.com"|
    end
  end
end
