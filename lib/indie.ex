defmodule Indie do
  @moduledoc """
  Indie keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  @doc "Directory where user uploads (e.g. Stonetop avatars) are written and served from."
  def uploads_dir do
    Application.get_env(:indie, :uploads_dir) ||
      Path.join(:code.priv_dir(:indie), "static/uploads")
  end
end
