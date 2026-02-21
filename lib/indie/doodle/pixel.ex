defmodule Indie.Doodle.Pixel do
  use Ecto.Schema
  import Ecto.Changeset

  schema "doodle_pixels" do
    field :x, :integer
    field :y, :integer
    field :color, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(pixel, attrs) do
    pixel
    |> cast(attrs, [:x, :y, :color])
    |> validate_required([:x, :y, :color])
    |> validate_format(:color, ~r/^#[0-9A-Fa-f]{6}$/)
    |> validate_number(:x, greater_than_or_equal_to: 0, less_than: 1920)
    |> validate_number(:y, greater_than_or_equal_to: 0, less_than: 1080)
    |> unique_constraint([:x, :y])
  end
end
