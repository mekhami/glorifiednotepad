defmodule Indie.DoodleAnimationTest do
  use Indie.DataCase

  alias Indie.Doodle
  alias Indie.Doodle.Animation

  describe "create_animation/1" do
    test "creates animation with valid attrs" do
      attrs = %{x1: 10, y1: 10, x2: 110, y2: 110}
      assert {:ok, %Animation{} = anim} = Doodle.create_animation(attrs)
      assert anim.x1 == 10
      assert anim.frame_count == 1
      assert anim.fps == 4
    end

    test "rejects region wider than 200 units" do
      attrs = %{x1: 0, y1: 0, x2: 201, y2: 100}
      assert {:error, changeset} = Doodle.create_animation(attrs)
      assert %{x2: [_]} = errors_on(changeset)
    end

    test "rejects region taller than 200 units" do
      attrs = %{x1: 0, y1: 0, x2: 100, y2: 201}
      assert {:error, changeset} = Doodle.create_animation(attrs)
      assert %{x2: [_]} = errors_on(changeset)
    end

    test "allows exactly 200x200 region" do
      attrs = %{x1: 0, y1: 0, x2: 200, y2: 200}
      assert {:ok, _} = Doodle.create_animation(attrs)
    end
  end

  describe "list_animations/0" do
    test "returns empty list when no animations" do
      assert Doodle.list_animations() == []
    end

    test "returns all saved animations" do
      {:ok, _} = Doodle.create_animation(%{x1: 0, y1: 0, x2: 50, y2: 50})
      {:ok, _} = Doodle.create_animation(%{x1: 100, y1: 100, x2: 150, y2: 150})
      assert length(Doodle.list_animations()) == 2
    end
  end

  describe "get_animation!/1" do
    test "returns the animation" do
      {:ok, anim} = Doodle.create_animation(%{x1: 0, y1: 0, x2: 50, y2: 50})
      assert Doodle.get_animation!(anim.id).id == anim.id
    end

    test "raises on missing id" do
      assert_raise Ecto.NoResultsError, fn -> Doodle.get_animation!(999_999) end
    end
  end

  describe "update_animation/2" do
    test "updates frame_count" do
      {:ok, anim} = Doodle.create_animation(%{x1: 0, y1: 0, x2: 50, y2: 50})
      {:ok, updated} = Doodle.update_animation(anim, %{frame_count: 5})
      assert updated.frame_count == 5
    end

    test "rejects frame_count > 8" do
      {:ok, anim} = Doodle.create_animation(%{x1: 0, y1: 0, x2: 50, y2: 50})
      {:error, changeset} = Doodle.update_animation(anim, %{frame_count: 9})
      assert %{frame_count: [_]} = errors_on(changeset)
    end
  end

  describe "save_animation_frames/2 and get_animation_pixels/1" do
    test "saves frames and retrieves pixels grouped by frame" do
      {:ok, anim} = Doodle.create_animation(%{x1: 0, y1: 0, x2: 50, y2: 50})

      frames = [
        %{"frame" => 0, "pixels" => [%{"x" => 5, "y" => 5, "color" => "#FF0000"}]},
        %{"frame" => 1, "pixels" => [%{"x" => 5, "y" => 5, "color" => "#0000FF"}]}
      ]

      :ok = Doodle.save_animation_frames(anim.id, frames)

      by_frame = Doodle.get_animation_pixels(anim.id)

      assert [%{x: 5, y: 5, color: "#FF0000", frame: 0}] = Map.get(by_frame, 0)
      assert [%{x: 5, y: 5, color: "#0000FF", frame: 1}] = Map.get(by_frame, 1)
    end

    test "save_animation_frames replaces existing frame data" do
      {:ok, anim} = Doodle.create_animation(%{x1: 0, y1: 0, x2: 50, y2: 50})

      Doodle.save_animation_frames(anim.id, [
        %{"frame" => 0, "pixels" => [%{"x" => 1, "y" => 1, "color" => "#FF0000"}]}
      ])

      Doodle.save_animation_frames(anim.id, [
        %{"frame" => 0, "pixels" => [%{"x" => 2, "y" => 2, "color" => "#00FF00"}]}
      ])

      by_frame = Doodle.get_animation_pixels(anim.id)
      frame0 = Map.get(by_frame, 0, [])

      # Old pixel gone, new pixel present
      refute Enum.any?(frame0, &(&1.x == 1 and &1.y == 1))
      assert Enum.any?(frame0, &(&1.x == 2 and &1.y == 2))
    end
  end

  describe "delete_animation/1" do
    test "deletes animation and cascades to pixels" do
      {:ok, anim} = Doodle.create_animation(%{x1: 0, y1: 0, x2: 50, y2: 50})

      Doodle.save_animation_frames(anim.id, [
        %{"frame" => 0, "pixels" => [%{"x" => 5, "y" => 5, "color" => "#FF0000"}]}
      ])

      Doodle.delete_animation(anim.id)

      assert Doodle.list_animations() == []
      assert Doodle.get_animation_pixels(anim.id) == %{}
    end
  end
end
