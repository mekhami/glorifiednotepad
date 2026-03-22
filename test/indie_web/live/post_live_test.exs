defmodule IndieWeb.PostLiveTest do
  use IndieWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "mount/3" do
    test "assigns pixel colors to post", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/p/d20-ways-get-rpg-unstuck")

      post = :sys.get_state(view.pid).socket.assigns.post

      # Verify post has pixel_colors
      assert Map.has_key?(post, :pixel_colors)
      assert is_list(post.pixel_colors)
    end

    test "post has 18 pixel colors", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/p/d20-ways-get-rpg-unstuck")

      post = :sys.get_state(view.pid).socket.assigns.post

      assert length(post.pixel_colors) == 18
    end

    test "pixel colors are deterministic for same post", %{conn: conn} do
      {:ok, view1, _html} = live(conn, "/p/d20-ways-get-rpg-unstuck")
      post1 = :sys.get_state(view1.pid).socket.assigns.post

      {:ok, view2, _html} = live(conn, "/p/d20-ways-get-rpg-unstuck")
      post2 = :sys.get_state(view2.pid).socket.assigns.post

      # Verify same post has same pixel colors across different mounts
      assert post1.id == post2.id
      assert post1.pixel_colors == post2.pixel_colors
    end

    test "all pixel colors are valid hex codes", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/p/d20-ways-get-rpg-unstuck")

      post = :sys.get_state(view.pid).socket.assigns.post

      Enum.each(post.pixel_colors, fn color ->
        assert String.match?(color, ~r/^#[0-9A-F]{6}$/i)
      end)
    end

    test "post not found does not have pixel colors", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/p/non-existent-post")

      post = :sys.get_state(view.pid).socket.assigns.post

      # Verify post is nil for non-existent posts
      assert post == nil
    end
  end

  describe "generate_pixel_colors/2" do
    test "generates 18 colors by default" do
      colors = IndieWeb.Pixels.generate_pixel_colors("test-post-1")

      assert length(colors) == 18
    end

    test "all colors are valid hex codes" do
      colors = IndieWeb.Pixels.generate_pixel_colors("test-post-1")

      Enum.each(colors, fn color ->
        assert String.match?(color, ~r/^#[0-9A-F]{6}$/i)
      end)
    end

    test "same post ID generates same pattern" do
      colors1 = IndieWeb.Pixels.generate_pixel_colors("same-id")
      colors2 = IndieWeb.Pixels.generate_pixel_colors("same-id")

      assert colors1 == colors2
    end

    test "different post IDs generate different patterns" do
      colors1 = IndieWeb.Pixels.generate_pixel_colors("post-1")
      colors2 = IndieWeb.Pixels.generate_pixel_colors("post-2")

      assert colors1 != colors2
    end

    test "respects custom pixel count" do
      colors = IndieWeb.Pixels.generate_pixel_colors("test-post", 10)

      assert length(colors) == 10
    end

    test "handles zero count" do
      colors = IndieWeb.Pixels.generate_pixel_colors("test-post", 0)

      assert colors == []
    end

    test "generates colors from predefined palette" do
      colors = IndieWeb.Pixels.generate_pixel_colors("test-post")

      # Define the same palette as in the implementation
      palette = [
        "#FF00FF",
        "#00FFFF",
        "#FFFF00",
        "#FF6B6B",
        "#4ECDC4",
        "#95E1D3",
        "#F38181",
        "#AA96DA",
        "#FCBAD3",
        "#FFFFD2",
        "#A8E6CF",
        "#FFD3B6",
        "#FFAAA5",
        "#FF8B94",
        "#6C5CE7",
        "#FD79A8",
        "#FDCB6E",
        "#00B894"
      ]

      # Verify all generated colors are from the palette
      Enum.each(colors, fn color ->
        assert color in palette
      end)
    end
  end
end
