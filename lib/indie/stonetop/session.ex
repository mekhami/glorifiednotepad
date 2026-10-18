defmodule Indie.Stonetop.Session do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "stonetop_sessions" do
    field(:number, :integer)
    field(:title, :string)
    field(:played_on, :date)
    field(:notes, :string, default: "")

    timestamps()
  end

  @doc """
  A URL-friendly version of the session's title, e.g. "The Hollow Road" ->
  "the-hollow-road". Untitled sessions fall back to "session-<number>".
  """
  def slug(%__MODULE__{title: title, number: number}) do
    (title || "")
    |> String.normalize(:nfd)
    |> String.replace(~r/\p{Mn}/u, "")
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
    |> case do
      "" -> "session-#{number}"
      slug -> slug
    end
  end

  @doc false
  def changeset(session, attrs) do
    session
    |> cast(attrs, [:number, :title, :played_on, :notes])
    |> then(&if(get_field(&1, :notes), do: &1, else: put_change(&1, :notes, "")))
    |> validate_required([:number])
    |> validate_number(:number, greater_than: 0)
    |> validate_length(:title, max: 200)
    |> unique_constraint(:number, message: "already has notes")
  end
end
