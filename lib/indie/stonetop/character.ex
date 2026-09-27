defmodule Indie.Stonetop.Character do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "characters" do
    field :name, :string
    field :description, :string
    field :tags, {:array, :string}, default: []
    field :image_url, :string
    field :position_x, :float, default: 0.0
    field :position_y, :float, default: 0.0

    timestamps()
  end

  @doc false
  def changeset(character, attrs) do
    character
    |> cast(attrs, [:name, :description, :tags, :image_url, :position_x, :position_y])
    |> validate_required([:name])
    |> validate_length(:name, max: 100)
    |> validate_length(:description, max: 5000)
  end
end
