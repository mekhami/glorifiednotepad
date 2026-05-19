defmodule Indie.Repo.Migrations.CreateAnimations do
  use Ecto.Migration

  def change do
    create table(:animations) do
      add :x1, :integer, null: false
      add :y1, :integer, null: false
      add :x2, :integer, null: false
      add :y2, :integer, null: false
      add :frame_count, :integer, null: false, default: 1
      add :fps, :integer, null: false, default: 4

      timestamps(type: :utc_datetime)
    end
  end
end
