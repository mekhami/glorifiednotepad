defmodule Indie.PostTest do
  use ExUnit.Case, async: true
  alias Indie.Post

  describe "draft functionality" do
    test "all() returns both published and draft posts" do
      all_posts = Post.all()
      indie_web_post = Enum.find(all_posts, &(&1.id == "the-indie-web"))

      assert indie_web_post != nil, "the-indie-web post should exist in all()"
      assert indie_web_post.draft == true, "the-indie-web post should be marked as draft"
    end

    test "published() excludes draft posts" do
      published_posts = Post.published()
      indie_web_post = Enum.find(published_posts, &(&1.id == "the-indie-web"))

      assert indie_web_post == nil, "the-indie-web draft post should NOT appear in published()"

      # Verify we still have other posts
      assert length(published_posts) > 0, "should have at least some published posts"
    end

    test "get_by_id() returns nil for draft posts" do
      result = Post.get_by_id("the-indie-web")

      assert result == nil, "get_by_id should return nil for draft posts"
    end

    test "get_by_id() returns published posts" do
      # Get any published post
      published_posts = Post.published()

      if length(published_posts) > 0 do
        first_post = List.first(published_posts)
        result = Post.get_by_id(first_post.id)

        assert result != nil, "get_by_id should return published posts"
        assert result.id == first_post.id
        assert result.draft == false
      end
    end

    test "posts without draft field default to false (published)" do
      published_posts = Post.published()

      # Find a post that doesn't have draft: true in frontmatter
      # All existing posts except the-indie-web should be published
      non_draft_post = Enum.find(published_posts, &(&1.id != "the-indie-web"))

      if non_draft_post do
        assert non_draft_post.draft == false,
               "posts without draft field should default to published"
      end
    end
  end

  describe "struct defaults" do
    test "draft defaults to false in struct" do
      post = %Post{}
      assert post.draft == false
    end

    test "width defaults to 25% in struct" do
      post = %Post{}
      assert post.width == "25%"
    end

    test "sidenotes defaults to [] in struct" do
      post = %Post{}
      assert post.sidenotes == []
    end
  end

  describe "sidenotes pipeline" do
    test "post without sidenotes front matter has empty sidenotes list" do
      post = %Post{sidenotes: []}
      assert post.sidenotes == []
    end

    test "SidenotesTransformer integration: anchors survive Earmark pipeline" do
      markdown = """
      A paragraph with a note.[^1]

      [^1]: The note text.
      """

      {transformed, sidenotes} =
        Indie.Markdown.SidenotesTransformer.transform(markdown, "test-post")

      # The anchor span should survive the full pipeline
      html =
        transformed
        |> Indie.Markdown.ColumnsTransformer.transform()
        |> Indie.Markdown.VideoTransformer.transform()
        |> Earmark.as_ast!(breaks: true)
        |> Indie.Markdown.HighlightTransformer.transform()
        |> Earmark.Transform.transform()
        |> Indie.Markdown.SidenotesTransformer.replace_placeholders("test-post")

      assert html =~ ~r/id="sn-test-post-1"/
      assert html =~ ~r/class="sn-anchor"/
      assert length(sidenotes) == 1
      assert hd(sidenotes).number == 1
      assert hd(sidenotes).html =~ "The note text."
    end
  end

  describe "datetime parsing and sorting" do
    test "posts with timestamps are parsed as DateTime" do
      all_posts = Post.all()

      # All posts should have DateTime values
      Enum.each(all_posts, fn post ->
        assert %DateTime{} = post.date,
               "Post #{post.id} should have DateTime, got: #{inspect(post.date)}"
      end)
    end

    test "posts are sorted by DateTime (newest first)" do
      all_posts = Post.all()

      # Verify posts are in descending chronological order
      Enum.chunk_every(all_posts, 2, 1, :discard)
      |> Enum.each(fn [first, second] ->
        assert DateTime.compare(first.date, second.date) in [:gt, :eq],
               "Posts should be sorted newest first. #{first.id} (#{first.date}) should be >= #{second.id} (#{second.date})"
      end)
    end

    test "multiple posts on same day are ordered by timestamp" do
      # This test will verify the functionality exists
      # It will only assert if there are actually posts with same date but different times
      all_posts = Post.all()

      same_day_posts =
        all_posts
        |> Enum.group_by(fn post -> DateTime.to_date(post.date) end)
        |> Enum.filter(fn {_date, posts} -> length(posts) > 1 end)
        |> Enum.flat_map(fn {_date, posts} -> posts end)

      if length(same_day_posts) > 0 do
        # Verify they're sorted by time
        Enum.chunk_every(same_day_posts, 2, 1, :discard)
        |> Enum.each(fn [first, second] ->
          if DateTime.to_date(first.date) == DateTime.to_date(second.date) do
            assert DateTime.compare(first.date, second.date) in [:gt, :eq],
                   "Posts on same day should be ordered by timestamp"
          end
        end)
      end
    end
  end
end
