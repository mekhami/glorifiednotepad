defmodule Indie.Repo.Migrations.CreateStonetop do
  use Ecto.Migration

  def change do
    create table(:characters, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text, default: ""
      add :tags, :map, default: %{}
      add :image_url, :string
      add :position_x, :float, default: 0.0
      add :position_y, :float, default: 0.0

      timestamps()
    end

    create table(:relationships, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :source_id, :binary_id, null: false
      add :target_id, :binary_id, null: false
      add :description, :text, default: ""
      add :tags, :map, default: %{}
      timestamps()
    end

    create index(:relationships, [:source_id])
    create index(:relationships, [:target_id])
    create unique_index(:relationships, [:source_id, :target_id])
  end
end