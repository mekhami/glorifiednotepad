defmodule Indie.Repo.Migrations.CreateStonetopFamily do
  use Ecto.Migration

  def change do
    create table(:parent_children, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :parent_id, references(:characters, type: :binary_id, on_delete: :delete_all),
        null: false

      add :child_id, references(:characters, type: :binary_id, on_delete: :delete_all),
        null: false

      add :kind, :string, null: false, default: "biological"

      timestamps()
    end

    create index(:parent_children, [:child_id])
    create unique_index(:parent_children, [:parent_id, :child_id])

    create constraint(:parent_children, :parent_child_not_self, check: "parent_id <> child_id")

    create table(:partnerships, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :partner_a_id, references(:characters, type: :binary_id, on_delete: :delete_all),
        null: false

      add :partner_b_id, references(:characters, type: :binary_id, on_delete: :delete_all),
        null: false

      add :status, :string, null: false, default: "married"

      timestamps()
    end

    create index(:partnerships, [:partner_b_id])
    create unique_index(:partnerships, [:partner_a_id, :partner_b_id])

    create constraint(:partnerships, :partnership_not_self,
             check: "partner_a_id <> partner_b_id"
           )
  end
end
