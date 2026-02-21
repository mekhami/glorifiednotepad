defmodule IndieWeb.Router do
  use IndieWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {IndieWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", IndieWeb do
    pipe_through(:browser)

    live("/", HomeLive)
    get("/feed.rss", FeedController, :rss)
  end

  # Other scopes may use custom stacks.
  # scope "/api", IndieWeb do
  #   pipe_through :api
  # end
end
