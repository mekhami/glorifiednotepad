defmodule Indie.Repo.Migrations.RemoveStonetopPositions do
  use Ecto.Migration

  def change do
    alter table(:characters) do
      remove :position_x
      remove :position_y
    end
  end
end