defmodule Indie.Doodle.Animation do
  use Ecto.Schema
  import Ecto.Changeset

  @max_dimension 200

  schema "animations" do
    field(:x1, :integer)
    field(:y1, :integer)
    field(:x2, :integer)
    field(:y2, :integer)
    field(:frame_count, :integer, default: 1)
    field(:fps, :integer, default: 4)

    timestamps(type: :utc_datetime)
  end

  def changeset(animation, attrs) do
    animation
    |> cast(attrs, [:x1, :y1, :x2, :y2, :frame_count, :fps])
    |> validate_required([:x1, :y1, :x2, :y2])
    |> validate_number(:x1, greater_than_or_equal_to: 0, less_than: 1920)
    |> validate_number(:y1, greater_than_or_equal_to: 0, less_than: 1080)
    |> validate_number(:x2, greater_than_or_equal_to: 0, less_than: 1920)
    |> validate_number(:y2, greater_than_or_equal_to: 0, less_than: 1080)
    |> validate_number(:frame_count, greater_than_or_equal_to: 1, less_than_or_equal_to: 8)
    |> validate_dimensions()
  end

  defp validate_dimensions(changeset) do
    x1 = get_field(changeset, :x1)
    y1 = get_field(changeset, :y1)
    x2 = get_field(changeset, :x2)
    y2 = get_field(changeset, :y2)

    if x1 && y1 && x2 && y2 do
      width = abs(x2 - x1)
      height = abs(y2 - y1)

      if width > @max_dimension or height > @max_dimension do
        add_error(changeset, :x2, "animation region cannot exceed 200×200 canvas units")
      else
        changeset
      end
    else
      changeset
    end
  end
end
