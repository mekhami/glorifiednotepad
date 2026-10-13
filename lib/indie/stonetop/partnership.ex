defmodule Indie.Stonetop.Partnership do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(married partnered divorced widowed)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "partnerships" do
    belongs_to(:partner_a, Indie.Stonetop.Character, foreign_key: :partner_a_id)
    belongs_to(:partner_b, Indie.Stonetop.Character, foreign_key: :partner_b_id)
    field(:status, :string, default: "married")

    timestamps()
  end

  def statuses, do: @statuses

  @doc false
  def changeset(partnership, attrs) do
    partnership
    |> cast(attrs, [:partner_a_id, :partner_b_id, :status])
    |> validate_required([:partner_a_id, :partner_b_id, :status])
    |> validate_inclusion(:status, @statuses)
    |> order_pair()
    |> validate_not_self()
    |> unique_constraint([:partner_a_id, :partner_b_id],
      name: :partnerships_partner_a_id_partner_b_id_index,
      message: "are already partners"
    )
    |> check_constraint(:partner_b_id,
      name: :partnership_not_self,
      message: "cannot partner with self"
    )
    |> foreign_key_constraint(:partner_a_id)
    |> foreign_key_constraint(:partner_b_id)
  end

  defp order_pair(changeset) do
    a = get_field(changeset, :partner_a_id)
    b = get_field(changeset, :partner_b_id)

    if a && b && a > b do
      changeset
      |> put_change(:partner_a_id, b)
      |> put_change(:partner_b_id, a)
    else
      changeset
    end
  end

  defp validate_not_self(changeset) do
    a = get_field(changeset, :partner_a_id)

    if a && a == get_field(changeset, :partner_b_id) do
      add_error(changeset, :partner_b_id, "cannot partner with self")
    else
      changeset
    end
  end
end
