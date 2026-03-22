defmodule IndieWeb.Live.PixelColorsTest do
  use ExUnit.Case, async: true

  # We'll test the private function by calling it through the LiveView module
  # using a test post ID
  describe "generate_pixel_colors" do
    test "generates 18 colors by default" do
      colors = IndieWeb.HomeLive.generate_pixel_colors("test-post-1")

      assert length(colors) == 18
    end

    test "all colors are valid hex codes" do
      colors = IndieWeb.HomeLive.generate_pixel_colors("test-post-1")

      Enum.each(colors, fn color ->
        assert String.match?(color, ~r/^#[0-9A-F]{6}$/i)
      end)
    end

    test "same post ID generates same pattern" do
      colors1 = IndieWeb.HomeLive.generate_pixel_colors("same-id")
      colors2 = IndieWeb.HomeLive.generate_pixel_colors("same-id")

      assert colors1 == colors2
    end

    test "different post IDs generate different patterns" do
      colors1 = IndieWeb.HomeLive.generate_pixel_colors("post-1")
      colors2 = IndieWeb.HomeLive.generate_pixel_colors("post-2")

      assert colors1 != colors2
    end

    test "respects custom pixel count" do
      colors = IndieWeb.HomeLive.generate_pixel_colors("test-post", 10)

      assert length(colors) == 10
    end

    test "handles zero pixel count" do
      colors = IndieWeb.HomeLive.generate_pixel_colors("test-post", 0)
      assert colors == []
    end

    test "handles large pixel counts" do
      colors = IndieWeb.HomeLive.generate_pixel_colors("test-post", 500)
      assert length(colors) == 500
      assert Enum.all?(colors, &String.match?(&1, ~r/^#[0-9a-fA-F]{6}$/))
    end
  end
end
