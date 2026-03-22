defmodule IndieWeb.HomeLiveTest do
  use IndieWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "mount/3" do
    test "assigns pixel colors to posts", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      posts = :sys.get_state(view.pid).socket.assigns.posts

      # Verify all posts have pixel_colors
      assert Enum.all?(posts, fn post ->
               Map.has_key?(post, :pixel_colors) && is_list(post.pixel_colors)
             end)
    end

    test "pixel colors are deterministic for same post", %{conn: conn} do
      {:ok, view1, _html} = live(conn, "/")
      posts1 = :sys.get_state(view1.pid).socket.assigns.posts

      {:ok, view2, _html} = live(conn, "/")
      posts2 = :sys.get_state(view2.pid).socket.assigns.posts

      # Verify same posts have same pixel colors across different mounts
      Enum.zip(posts1, posts2)
      |> Enum.each(fn {post1, post2} ->
        assert post1.id == post2.id
        assert post1.pixel_colors == post2.pixel_colors
      end)
    end

    test "each post has 18 pixel colors", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      posts = :sys.get_state(view.pid).socket.assigns.posts

      Enum.each(posts, fn post ->
        assert length(post.pixel_colors) == 18
      end)
    end

    test "all pixel colors are valid hex codes", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      posts = :sys.get_state(view.pid).socket.assigns.posts

      Enum.each(posts, fn post ->
        Enum.each(post.pixel_colors, fn color ->
          assert String.match?(color, ~r/^#[0-9A-F]{6}$/i)
        end)
      end)
    end
  end

  describe "handle_event/3 load_more" do
    test "assigns pixel colors to newly loaded posts", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Trigger load_more event
      render_click(view, "load_more")

      posts = :sys.get_state(view.pid).socket.assigns.posts

      # Verify all posts (including newly loaded) have pixel_colors
      assert Enum.all?(posts, fn post ->
               Map.has_key?(post, :pixel_colors) && is_list(post.pixel_colors)
             end)
    end

    test "newly loaded posts have deterministic pixel colors", %{conn: conn} do
      # Mount and get initial posts
      {:ok, view1, _html} = live(conn, "/")
      initial_posts = :sys.get_state(view1.pid).socket.assigns.posts

      # Load more posts
      render_click(view1, "load_more")
      posts_after_load = :sys.get_state(view1.pid).socket.assigns.posts

      # Verify initial posts still have same pixel colors
      initial_posts
      |> Enum.with_index()
      |> Enum.each(fn {initial_post, idx} ->
        loaded_post = Enum.at(posts_after_load, idx)
        assert initial_post.id == loaded_post.id
        assert initial_post.pixel_colors == loaded_post.pixel_colors
      end)
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
  end

  describe "pixel strip rendering" do
    test "renders pixel strip container for each post", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      # Count post headers - should match number of pixel strip containers
      post_header_count = html |> String.split("post-header-pixels") |> length() |> Kernel.-(1)

      assert post_header_count > 0
    end

    test "renders 18 pixel spans per post", %{conn: conn} do
      {:ok, view, html} = live(conn, "/")

      posts = :sys.get_state(view.pid).socket.assigns.posts

      # Check that we have 18 pixel spans for the first post
      # We'll look for spans with class="pixel" within the first post-header-pixels container
      assert html =~ ~s(class="post-header-pixels")
      assert html =~ ~s(class="pixel")

      # Count pixel spans - should be 18 per post
      pixel_count = html |> String.split(~s(class="pixel")) |> length() |> Kernel.-(1)
      expected_pixel_count = length(posts) * 18

      assert pixel_count == expected_pixel_count
    end

    test "pixels have inline background color styles", %{conn: conn} do
      {:ok, view, html} = live(conn, "/")

      posts = :sys.get_state(view.pid).socket.assigns.posts
      first_post = List.first(posts)

      # Verify that each pixel color from the first post appears in the HTML
      # with the inline style format: background: #XXXXXX;
      Enum.each(first_post.pixel_colors, fn color ->
        assert html =~ ~s(background: #{color};)
      end)
    end

    test "pixel strip is positioned within post header", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      # Verify that post-header-pixels appears inside post-header
      # by checking the structure in the HTML (allowing for additional attributes on pixel strip)
      assert html =~ ~r/<div class="post-header"[^>]*>.*?<div class="post-header-pixels"[^>]*>/s
    end
  end
end
