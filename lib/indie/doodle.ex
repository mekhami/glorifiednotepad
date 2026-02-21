defmodule Indie.Doodle do
  @moduledoc """
  The Doodle context for managing collaborative canvas pixels.
  """

  import Ecto.Query
  alias Indie.Repo
  alias Indie.Doodle.Pixel

  @background_color "#df9390"

  @doc """
  Returns the list of all pixels from the database.
  """
  def list_pixels do
    Repo.all(Pixel)
  end

  @doc """
  Saves a batch of pixels to the database.
  Filters out background color pixels and uses upsert to replace existing pixels.
  Returns the list of saved pixels.
  """
  def save_pixels(pixels) do
    # Filter out background color pixels
    pixels_to_save =
      pixels
      |> Enum.reject(fn p -> p["color"] == @background_color end)
      |> Enum.map(fn p ->
        %{
          x: p["x"],
          y: p["y"],
          color: p["color"],
          inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
          updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
        }
      end)

    # Only proceed if we have pixels to save
    if pixels_to_save != [] do
      # Upsert all pixels at once
      Repo.insert_all(
        Pixel,
        pixels_to_save,
        on_conflict: {:replace, [:color, :updated_at]},
        conflict_target: [:x, :y]
      )
    end

    pixels_to_save
  end

  @doc """
  Deletes a pixel at the given coordinates.
  Useful for eraser functionality if needed later.
  """
  def delete_pixel(x, y) do
    query = from p in Pixel, where: p.x == ^x and p.y == ^y
    Repo.delete_all(query)
  end
end
