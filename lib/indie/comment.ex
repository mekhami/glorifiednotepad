defmodule Indie.Comment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "comments" do
    field(:post_id, :string)
    field(:author_name, :string)
    field(:body, :string)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:post_id, :author_name, :body])
    |> validate_required([:post_id, :author_name, :body])
    |> validate_length(:author_name, max: 50, message: "must be 50 characters or less")
    |> validate_length(:body, max: 1000, message: "must be 1000 characters or less")
    |> update_change(:author_name, &String.trim/1)
    |> update_change(:body, &String.trim/1)
  end
end
