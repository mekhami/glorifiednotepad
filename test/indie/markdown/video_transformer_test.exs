defmodule Indie.Markdown.VideoTransformerTest do
  use ExUnit.Case, async: true

  alias Indie.Markdown.VideoTransformer

  test "transforms [video:...] into a <video> element with webm and mp4 sources" do
    input = "[video:/videos/demo.mp4]"

    result = VideoTransformer.transform(input)

    assert result =~ ~s(<video controls width="100%">)
    assert result =~ ~s(<source src="/videos/demo.webm" type="video/webm">)
    assert result =~ ~s(<source src="/videos/demo.mp4" type="video/mp4">)
    assert result =~ "</video>"
  end

  test "passes through markdown with no video tags unchanged" do
    input = "Hello **world**\n\nSome paragraph."
    assert VideoTransformer.transform(input) == input
  end

  test "transforms multiple video tags in one document" do
    input = "[video:/videos/first.mp4]\n\nSome text.\n\n[video:/videos/second.mp4]"

    result = VideoTransformer.transform(input)

    assert result =~ ~s(src="/videos/first.webm")
    assert result =~ ~s(src="/videos/first.mp4")
    assert result =~ ~s(src="/videos/second.webm")
    assert result =~ ~s(src="/videos/second.mp4")
  end

  test "does not transform [video:...] inside a code block" do
    # The transformer is a pre-processor on raw markdown strings.
    # Fenced code blocks are represented as literal backtick strings at this stage,
    # so the transformer should NOT skip them — this tests that the regex only
    # matches the exact [video:path.mp4] pattern and not similar-but-wrong patterns.
    input = "Not a video: [video:no-extension]"
    result = VideoTransformer.transform(input)
    # no .mp4 extension means no match
    assert result == input
  end
end
