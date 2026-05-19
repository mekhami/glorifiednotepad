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
    Repo.all(from(p in Pixel, where: is_nil(p.animation_id)))
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
        end

        %{x: x, y: y}
      end)

    # Handle saves — tag each pixel with its animation (or nil) in one pass
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    tagged_pixels =
      pixels_to_save
      |> Enum.reject(fn p ->
        x = p["x"]
        y = p["y"]
        x < 0 or x >= @canvas_width or y < 0 or y >= @canvas_height
      end)
      |> Enum.map(fn p ->
        {p, find_animation_for_pixel(p["x"], p["y"], animations)}
      end)

    # Save ALL pixels as static — pixels drawn outside the editor always win.
    static_pixel_data =
      Enum.map(tagged_pixels, fn {p, _anim} ->
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

    # For pixels that hit animation regions, delete those coords from all frames
    # so the static pixel is not hidden under the animation layer.
    modified_animation_ids =
      tagged_pixels
      |> Enum.filter(fn {_p, anim} -> not is_nil(anim) end)
      |> Enum.group_by(fn {_p, anim} -> anim.id end)
      |> Enum.map(fn {animation_id, tagged} ->
        Enum.each(tagged, fn {p, _} ->
          delete_pixel_from_all_frames(p["x"], p["y"], animation_id)
        end)

        animation_id
      end)

    %{
      saved: static_pixel_data,
      deleted: deleted_coords,
      modified_animation_ids: modified_animation_ids
    }
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

  @doc """
  Saves animation frames for the given animation struct.
  - Validates pixel coords are within animation bounding box (rejects out-of-bounds silently).
  - Deletes pixels from other animations where (x, y, frame) matches B's saved tuples.
  - Deletes animation records that end up with zero pixels.
  Returns {:ok, %{deleted_animation_ids: [integer]}}.
  """
  def save_animation_frames(%Animation{} = animation, frames) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    animation_id = animation.id
    min_x = min(animation.x1, animation.x2)
    max_x = max(animation.x1, animation.x2)
    min_y = min(animation.y1, animation.y2)
    max_y = max(animation.y1, animation.y2)

    # 1. Delete all existing pixels for this animation
    Repo.delete_all(from(p in Pixel, where: p.animation_id == ^animation_id))

    # 2. Build validated pixel rows
    pixels_to_insert =
      Enum.flat_map(frames, fn frame_data ->
        frame_index = frame_data["frame"]

        frame_data["pixels"]
        |> Enum.filter(fn p ->
          p["x"] >= min_x and p["x"] <= max_x and
            p["y"] >= min_y and p["y"] <= max_y
        end)
        |> Enum.map(fn p ->
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

    # 3. Find other animations with pixels at the same (x, y, frame) positions
    b_pixel_query =
      from(p in Pixel,
        where: p.animation_id == ^animation_id,
        select: %{x: p.x, y: p.y, frame: p.frame}
      )

    affected_animation_ids =
      if pixels_to_insert != [] do
        Repo.all(
          from(p in Pixel,
            join: b in subquery(b_pixel_query),
            on: p.x == b.x and p.y == b.y and p.frame == b.frame,
            where: p.animation_id != ^animation_id and not is_nil(p.animation_id),
            select: p.animation_id,
            distinct: true
          )
        )
      else
        []
      end

    # 4. Delete those overlapping pixels from the affected animations
    if affected_animation_ids != [] do
      overlapping_pixel_ids =
        Repo.all(
          from(p in Pixel,
            join: b in subquery(b_pixel_query),
            on: p.x == b.x and p.y == b.y and p.frame == b.frame,
            where: p.animation_id in ^affected_animation_ids,
            select: p.id
          )
        )

      if overlapping_pixel_ids != [] do
        Repo.delete_all(from(p in Pixel, where: p.id in ^overlapping_pixel_ids))
      end
    end

    # 5. Find which affected animations are now empty
    surviving_ids =
      if affected_animation_ids != [] do
        Repo.all(
          from(p in Pixel,
            where: p.animation_id in ^affected_animation_ids,
            select: p.animation_id,
            distinct: true
          )
        )
      else
        []
      end

    deleted_animation_ids = affected_animation_ids -- surviving_ids

    # 6. Delete the empty animation records
    if deleted_animation_ids != [] do
      Repo.delete_all(from(a in Animation, where: a.id in ^deleted_animation_ids))
    end

    {:ok, %{deleted_animation_ids: deleted_animation_ids}}
  end

  def get_animation_pixels(animation_id) do
    from(p in Pixel,
      where: p.animation_id == ^animation_id,
      select: %{x: p.x, y: p.y, color: p.color, frame: p.frame}
    )
    |> Repo.all()
    |> Enum.group_by(& &1.frame)
  end

  @doc """
  Returns all animation pixels grouped by animation_id, then by frame index.
  Returns %{animation_id => %{frame_index => [%{x, y, color}]}}.
  Single query — use this instead of calling get_animation_pixels/1 per animation.
  """
  def get_all_animation_pixels do
    from(p in Pixel,
      where: not is_nil(p.animation_id),
      select: %{x: p.x, y: p.y, color: p.color, frame: p.frame, animation_id: p.animation_id}
    )
    |> Repo.all()
    |> Enum.group_by(& &1.animation_id)
    |> Map.new(fn {anim_id, pixels} ->
      frames =
        pixels
        |> Enum.group_by(& &1.frame)
        |> Map.new(fn {frame_idx, frame_pixels} ->
          {frame_idx, Enum.map(frame_pixels, fn p -> %{x: p.x, y: p.y, color: p.color} end)}
        end)

      {anim_id, frames}
    end)
  end

  def delete_animation(id) do
    Repo.delete_all(from(a in Animation, where: a.id == ^id))
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
end
