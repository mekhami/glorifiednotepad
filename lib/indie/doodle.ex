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
  Background color pixels are deleted (eraser functionality).
  Other pixels are upserted to replace existing pixels.
  Returns a map with :saved and :deleted pixel lists.
  """
  def save_pixels(pixels) do
    # Separate background color pixels (to delete) from regular pixels (to save)
    {pixels_to_delete, pixels_to_save} =
      pixels
      |> Enum.split_with(fn p -> p["color"] == @background_color end)

    # Delete background color pixels
    deleted_coords =
      pixels_to_delete
      |> Enum.map(fn p ->
        delete_pixel(p["x"], p["y"])
        %{x: p["x"], y: p["y"]}
      end)

    # Save non-background pixels
    saved_pixels =
      pixels_to_save
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
    if saved_pixels != [] do
      # Upsert all pixels at once
      Repo.insert_all(
        Pixel,
        saved_pixels,
        on_conflict: {:replace, [:color, :updated_at]},
        conflict_target: [:x, :y]
      )
    end

    %{saved: saved_pixels, deleted: deleted_coords}
  end

  @doc """
  Deletes a pixel at the given coordinates.
  Useful for eraser functionality if needed later.
  """
  def delete_pixel(x, y) do
    query = from(p in Pixel, where: p.x == ^x and p.y == ^y)
    Repo.delete_all(query)
  end
end
