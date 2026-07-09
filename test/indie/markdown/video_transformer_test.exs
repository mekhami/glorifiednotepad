defmodule Indie.Markdown.VideoTransformerTest do
  use ExUnit.Case, async: true

  alias Indie.Markdown.VideoTransformer

  test "transforms [video:...] into a <video> element with webm and mp4 sources" do
    input = "[video:/videos/demo.mp4]"

    result = VideoTransformer.transform(input)

    assert result =~ ~s(<video controls width="100%" preload="none">)
    assert result =~ ~s(<source src="/videos/demo.webm" type="video/webm" />)
    assert result =~ ~s(<source src="/videos/demo.mp4" type="video/mp4" />)
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

  test "does not match [video:...] without .mp4 extension" do
    # The regex requires a .mp4 extension — patterns without it are left unchanged.
    input = "Not a video: [video:no-extension]"
    result = VideoTransformer.transform(input)
    # no .mp4 extension means no match
    assert result == input
  end
end
