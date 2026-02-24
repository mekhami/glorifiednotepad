defmodule Indie.Repo.Migrations.DeleteOutOfBoundsPixels do
  use Ecto.Migration

  def up do
    # Delete pixels outside the canvas boundary (1920x1080)
    execute """
    DELETE FROM doodle_pixels
    WHERE x >= 1920 OR x < 0 OR y >= 1080 OR y < 0
    """
  end

  def down do
    # This is a destructive operation - cannot restore deleted data
    :ok
  end
end
