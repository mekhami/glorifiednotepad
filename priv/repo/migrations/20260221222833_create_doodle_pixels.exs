defmodule Indie.Repo.Migrations.CreateDoodlePixels do
  use Ecto.Migration

  def change do
    create table(:doodle_pixels) do
      add :x, :integer, null: false
      add :y, :integer, null: false
      add :color, :string, null: false, size: 7  # "#RRGGBB"
      
      timestamps(type: :utc_datetime)
    end
    
    # Composite unique index - only one color per coordinate
    create unique_index(:doodle_pixels, [:x, :y])
    
    # Index for efficient querying
    create index(:doodle_pixels, [:x])
    create index(:doodle_pixels, [:y])
  end
end
