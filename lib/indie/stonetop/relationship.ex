defmodule Indie.Stonetop.Relationship do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "relationships" do
    belongs_to :source, Indie.Stonetop.Character, foreign_key: :source_id
    belongs_to :target, Indie.Stonetop.Character, foreign_key: :target_id
    field :description, :string
    field :tags, {:array, :string}, default: []

    timestamps()
  end

  @doc false
  def changeset(relationship, attrs) do
    relationship
    |> cast(attrs, [:source_id, :target_id, :description, :tags])
    |> validate_required([:source_id, :target_id])
    |> validate_length(:description, max: 5000)
    |> unique_constraint(:source_id, name: :relationships_source_id_target_id_index)
  end
end
