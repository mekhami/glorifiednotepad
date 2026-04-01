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

  pipeline :admin do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {IndieWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(IndieWeb.Plugs.RequireBasicAuth)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", IndieWeb do
    pipe_through(:browser)

    live("/", HomeLive)
    live("/p/:slug", PostLive)
    live("/podloader", PodloaderLive)
    get("/feed.rss", FeedController, :rss)
  end

  scope "/admin", IndieWeb.Admin do
    pipe_through(:admin)

    live_session :admin, on_mount: {IndieWeb.Admin.AdminLive, :admin} do
      live("/comments", CommentModerationLive, :index)
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", IndieWeb do
  #   pipe_through :api
  # end
end
