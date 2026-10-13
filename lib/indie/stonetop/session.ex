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
