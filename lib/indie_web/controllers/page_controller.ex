defmodule IndieWeb.PageController do
  use IndieWeb, :controller

  def home(conn, _params) do
    posts = Indie.Post.all()
    render(conn, :home, posts: posts)
  end
end
