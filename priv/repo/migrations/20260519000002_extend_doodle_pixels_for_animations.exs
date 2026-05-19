defmodule Indie.Repo.Migrations.ExtendDoodlePixelsForAnimations do
  use Ecto.Migration

  def change do
    alter table(:doodle_pixels) do
      add :animation_id, references(:animations, on_delete: :delete_all), null: true
      add :frame, :integer, null: true
    end

    # Drop the existing full unique index on (x, y)
    drop unique_index(:doodle_pixels, [:x, :y])

    # Partial unique index for static pixels (animation_id IS NULL)
    create unique_index(:doodle_pixels, [:x, :y],
      where: "animation_id IS NULL",
      name: "doodle_pixels_x_y_static_unique"
    )

    # Partial unique index for animated pixels (animation_id IS NOT NULL)
    create unique_index(:doodle_pixels, [:x, :y, :animation_id, :frame],
      where: "animation_id IS NOT NULL",
      name: "doodle_pixels_x_y_anim_frame_unique"
    )

    create index(:doodle_pixels, [:animation_id])
  end
end
