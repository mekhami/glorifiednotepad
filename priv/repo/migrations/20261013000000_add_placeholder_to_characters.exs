defmodule Indie.Repo.Migrations.AddPlaceholderToCharacters do
  use Ecto.Migration

  def change do
    alter table(:characters) do
      add :placeholder, :boolean, null: false, default: false
    end
  end
end
