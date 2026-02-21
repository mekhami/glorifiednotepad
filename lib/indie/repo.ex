defmodule Indie.Repo do
  use Ecto.Repo,
    otp_app: :indie,
    adapter: Ecto.Adapters.SQLite3
end
