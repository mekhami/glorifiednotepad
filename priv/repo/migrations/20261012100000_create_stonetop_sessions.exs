defmodule Indie.Repo.Migrations.CreateStonetopSessions do
  use Ecto.Migration

  def change do
    create table(:stonetop_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :number, :integer, null: false
      add :title, :string
      add :played_on, :date
      add :notes, :text, null: false, default: ""

      timestamps()
    end

    create unique_index(:stonetop_sessions, [:number])
  end
end
