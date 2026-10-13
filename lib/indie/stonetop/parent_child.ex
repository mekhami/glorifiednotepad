defmodule Indie.Stonetop.ParentChild do
  use Ecto.Schema
  import Ecto.Changeset

  @kinds ~w(biological adopted step)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "parent_children" do
    belongs_to(:parent, Indie.Stonetop.Character, foreign_key: :parent_id)
    belongs_to(:child, Indie.Stonetop.Character, foreign_key: :child_id)
    field(:kind, :string, default: "biological")

    timestamps()
  end

  def kinds, do: @kinds

  @doc false
  def changeset(parent_child, attrs) do
    parent_child
    |> cast(attrs, [:parent_id, :child_id, :kind])
    |> validate_required([:parent_id, :child_id, :kind])
    |> validate_inclusion(:kind, @kinds)
    |> validate_not_self()
    |> unique_constraint([:parent_id, :child_id],
      name: :parent_children_parent_id_child_id_index,
      message: "is already a parent of this child"
    )
    |> check_constraint(:child_id, name: :parent_child_not_self, message: "cannot be own parent")
    |> foreign_key_constraint(:parent_id)
    |> foreign_key_constraint(:child_id)
  end

  defp validate_not_self(changeset) do
    if get_field(changeset, :parent_id) &&
         get_field(changeset, :parent_id) == get_field(changeset, :child_id) do
      add_error(changeset, :child_id, "cannot be own parent")
    else
      changeset
    end
  end
end
