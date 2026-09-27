defmodule Indie.Repo.Migrations.AddFkCascadeToRelationships do
  use Ecto.Migration

  def change do
    alter table(:relationships) do
      modify :source_id, references(:characters, type: :binary_id, on_delete: :delete_all), null: false
      modify :target_id, references(:characters, type: :binary_id, on_delete: :delete_all), null: false
    end
  end
end
