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
    animations = list_animations()

    {pixels_to_delete, pixels_to_save} =
      Enum.split_with(pixels, fn p -> p["color"] == @background_color end)

    # Handle deletions
    deleted_coords =
      Enum.map(pixels_to_delete, fn p ->
        x = p["x"]
        y = p["y"]

        case find_animation_for_pixel(x, y, animations) do
          nil ->
            delete_pixel(x, y)

          animation ->
            delete_pixel_from_all_frames(x, y, animation.id)
            notify_animation_server(animation.id)
        end

        %{x: x, y: y}
      end)

    # Handle saves — split animated vs static
    valid_pixels =
      Enum.reject(pixels_to_save, fn p ->
        x = p["x"]
        y = p["y"]
        x < 0 or x >= @canvas_width or y < 0 or y >= @canvas_height
      end)

    {animated_pixels, static_pixels} =
      Enum.split_with(valid_pixels, fn p ->
        find_animation_for_pixel(p["x"], p["y"], animations) != nil
      end)

    # Save static pixels
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    static_pixel_data =
      Enum.map(static_pixels, fn p ->
        %{x: p["x"], y: p["y"], color: p["color"], inserted_at: now, updated_at: now}
      end)

    if static_pixel_data != [] do
      Repo.insert_all(
        Pixel,
        static_pixel_data,
        on_conflict: {:replace, [:color, :updated_at]},
        conflict_target: {:unsafe_fragment, "(x, y) WHERE animation_id IS NULL"}
      )
    end

    # Save animated pixels (write to all frames)
    animated_pixels
    |> Enum.group_by(fn p ->
      find_animation_for_pixel(p["x"], p["y"], animations).id
    end)
    |> Enum.each(fn {animation_id, pixels} ->
      animation = Enum.find(animations, &(&1.id == animation_id))
      save_pixel_to_all_frames(pixels, animation, now)
      notify_animation_server(animation_id)
    end)

    %{saved: static_pixel_data, deleted: deleted_coords}
  end

  @doc """
  Deletes a pixel at the given coordinates.
  Useful for eraser functionality if needed later.
  """
  def delete_pixel(x, y) do
    query = from(p in Pixel, where: p.x == ^x and p.y == ^y and is_nil(p.animation_id))
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

    Repo.delete_all(from(p in Pixel, where: p.animation_id == ^animation_id))

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
    Repo.delete_all(from(a in Animation, where: a.id == ^id))
  end

  def start_all_animation_servers do
    list_animations()
    |> Enum.each(fn animation ->
      Indie.Doodle.AnimationSupervisor.start_animation(animation)
    end)
  end

  defp find_animation_for_pixel(x, y, animations) do
    Enum.find(animations, fn a ->
      min_x = min(a.x1, a.x2)
      max_x = max(a.x1, a.x2)
      min_y = min(a.y1, a.y2)
      max_y = max(a.y1, a.y2)
      x >= min_x and x <= max_x and y >= min_y and y <= max_y
    end)
  end

  defp delete_pixel_from_all_frames(x, y, animation_id) do
    Repo.delete_all(
      from(p in Pixel,
        where: p.x == ^x and p.y == ^y and p.animation_id == ^animation_id
      )
    )
  end

  defp save_pixel_to_all_frames(pixels, animation, now) do
    pixel_rows =
      for p <- pixels,
          frame <- 0..(animation.frame_count - 1) do
        %{
          x: p["x"],
          y: p["y"],
          color: p["color"],
          animation_id: animation.id,
          frame: frame,
          inserted_at: now,
          updated_at: now
        }
      end

    Enum.each(pixels, fn p ->
      delete_pixel_from_all_frames(p["x"], p["y"], animation.id)
    end)

    if pixel_rows != [] do
      Repo.insert_all(
        Pixel,
        pixel_rows,
        on_conflict: {:replace, [:color, :updated_at]},
        conflict_target:
          {:unsafe_fragment, "(x, y, animation_id, frame) WHERE animation_id IS NOT NULL"}
      )
    end
  end

  defp notify_animation_server(animation_id) do
    case Registry.lookup(Indie.Doodle.AnimationRegistry, animation_id) do
      [{pid, _}] -> send(pid, :reload_pixels)
      [] -> :ok
    end
  rescue
    ArgumentError -> :ok
  end
end
