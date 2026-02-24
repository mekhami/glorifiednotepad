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
        assert non_draft_post.draft == false, "posts without draft field should default to published"
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
  end
end
