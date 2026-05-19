defmodule Indie.Doodle do
  @moduledoc """
  The Doodle context for managing collaborative canvas pixels.
  """

  import Ecto.Query
  alias Indie.Repo
  alias Indie.Doodle.Pixel
  alias Indie.Doodle.Animation

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
  @canvas_width 1920
  @canvas_height 1080

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

    # Save non-background pixels, filtering out-of-bounds coordinates
    saved_pixels =
      pixels_to_save
      |> Enum.reject(fn p ->
        x = p["x"]
        y = p["y"]
        x < 0 or x >= @canvas_width or y < 0 or y >= @canvas_height
      end)
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

  def create_animation(attrs) do
    %Animation{}
    |> Animation.changeset(attrs)
    |> Repo.insert()
  end

  def list_animations do
    Repo.all(Animation)
  end

  def get_animation!(id) do
    Repo.get!(Animation, id)
  end

  def update_animation(animation, attrs) do
    animation
    |> Animation.changeset(attrs)
    |> Repo.update()
  end

  def save_animation_frames(animation_id, frames) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Repo.delete_all(from p in Pixel, where: p.animation_id == ^animation_id)

    pixels_to_insert =
      Enum.flat_map(frames, fn frame_data ->
        frame_index = frame_data["frame"]

        Enum.map(frame_data["pixels"], fn p ->
          %{
            x: p["x"],
            y: p["y"],
            color: p["color"],
            animation_id: animation_id,
            frame: frame_index,
            inserted_at: now,
            updated_at: now
          }
        end)
      end)

    if pixels_to_insert != [] do
      Repo.insert_all(Pixel, pixels_to_insert)
    end

    :ok
  end

  def get_animation_pixels(animation_id) do
    from(p in Pixel,
      where: p.animation_id == ^animation_id,
      select: %{x: p.x, y: p.y, color: p.color, frame: p.frame}
    )
    |> Repo.all()
    |> Enum.group_by(& &1.frame)
  end

  def delete_animation(id) do
    Repo.delete_all(from a in Animation, where: a.id == ^id)
  end
end
