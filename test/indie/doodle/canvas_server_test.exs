defmodule Indie.Doodle.CanvasServerTest do
  use Indie.DataCase

  alias Indie.Doodle
  alias Indie.Doodle.CanvasServer

  setup do
    # Reset cache to match the empty test DB before each test.
    # DataCase sandbox is already in shared mode at this point, so
    # the CanvasServer process can access the test's DB connection.
    CanvasServer.reload()
    :ok
  end

  describe "get_pixels/0" do
    test "returns empty list when no pixels in DB" do
      assert CanvasServer.get_pixels() == []
    end

    test "returns pixels loaded from DB after reload" do
      Doodle.save_pixels([%{"x" => 10, "y" => 20, "color" => "#FF0000"}])
      CanvasServer.reload()

      pixels = CanvasServer.get_pixels()
      assert Enum.any?(pixels, &(&1.x == 10 and &1.y == 20 and &1.color == "#FF0000"))
    end

    test "does not include animation pixels" do
      {:ok, anim} = Doodle.create_animation(%{x1: 0, y1: 0, x2: 50, y2: 50})

      {:ok, _} =
        Doodle.save_animation_frames(anim, [
          %{"frame" => 0, "pixels" => [%{"x" => 5, "y" => 5, "color" => "#0000FF"}]}
        ])

      CanvasServer.reload()

      # Animation pixels must not bleed into static pixel list
      refute Enum.any?(CanvasServer.get_pixels(), &(&1.x == 5 and &1.y == 5))
    end
  end

  describe "get_animations/0" do
    test "returns empty list when no animations" do
      assert CanvasServer.get_animations() == []
    end

    test "returns formatted animations with frames after reload" do
      {:ok, anim} = Doodle.create_animation(%{x1: 0, y1: 0, x2: 50, y2: 50})
      {:ok, updated} = Doodle.update_animation(anim, %{frame_count: 1})

      {:ok, _} =
        Doodle.save_animation_frames(updated, [
          %{"frame" => 0, "pixels" => [%{"x" => 5, "y" => 5, "color" => "#0000FF"}]}
        ])

      CanvasServer.reload()

      [a] = CanvasServer.get_animations()
      assert a.id == anim.id
      assert a.x1 == 0
      assert a.x2 == 50
      assert a.frame_count == 1
      assert %{0 => [%{x: 5, y: 5, color: "#0000FF"}]} = a.frames
    end
  end

  describe "update_pixels/2" do
    test "adds saved pixels" do
      CanvasServer.update_pixels([%{x: 5, y: 10, color: "#FF0000"}], [])

      pixels = CanvasServer.get_pixels()
      assert Enum.any?(pixels, &(&1.x == 5 and &1.y == 10 and &1.color == "#FF0000"))
    end

    test "removes deleted pixels" do
      CanvasServer.update_pixels([%{x: 5, y: 10, color: "#FF0000"}], [])
      CanvasServer.update_pixels([], [%{x: 5, y: 10}])

      refute Enum.any?(CanvasServer.get_pixels(), &(&1.x == 5 and &1.y == 10))
    end

    test "overwrites existing pixel with new color, no duplicates" do
      CanvasServer.update_pixels([%{x: 5, y: 10, color: "#FF0000"}], [])
      CanvasServer.update_pixels([%{x: 5, y: 10, color: "#00FF00"}], [])

      matching = Enum.filter(CanvasServer.get_pixels(), &(&1.x == 5 and &1.y == 10))
      assert length(matching) == 1
      assert hd(matching).color == "#00FF00"
    end

    test "deleting unknown coord is a no-op" do
      CanvasServer.update_pixels([], [%{x: 999, y: 999}])
      assert CanvasServer.get_pixels() == []
    end

    test "handles extra fields on saved pixel structs (e.g. inserted_at)" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      CanvasServer.update_pixels(
        [%{x: 3, y: 4, color: "#ABCDEF", inserted_at: now, updated_at: now}],
        []
      )

      [p] = CanvasServer.get_pixels()
      assert p == %{x: 3, y: 4, color: "#ABCDEF"}
    end
  end

  describe "update_animation_frames/2" do
    test "updates frames for animation already in cache" do
      {:ok, anim} = Doodle.create_animation(%{x1: 0, y1: 0, x2: 50, y2: 50})

      {:ok, _} =
        Doodle.save_animation_frames(anim, [
          %{"frame" => 0, "pixels" => [%{"x" => 5, "y" => 5, "color" => "#FF0000"}]}
        ])

      CanvasServer.reload()

      new_frames = %{0 => [%{x: 5, y: 5, color: "#00FF00"}]}
      CanvasServer.update_animation_frames(anim.id, new_frames)

      [a] = CanvasServer.get_animations()
      assert a.frames == %{0 => [%{x: 5, y: 5, color: "#00FF00"}]}
    end

    test "no-op and no crash when animation not in cache" do
      CanvasServer.update_animation_frames(999_999, %{0 => [%{x: 1, y: 1, color: "#FF0000"}]})
      assert CanvasServer.get_animations() == []
    end
  end

  describe "upsert_animation/2" do
    test "adds new animation not yet in cache" do
      {:ok, anim} = Doodle.create_animation(%{x1: 0, y1: 0, x2: 50, y2: 50})
      frames = %{0 => [%{x: 5, y: 5, color: "#FF0000"}]}

      CanvasServer.upsert_animation(anim, frames)

      [a] = CanvasServer.get_animations()
      assert a.id == anim.id
      assert a.x1 == 0 and a.x2 == 50
      assert a.frames == frames
    end

    test "updates metadata when animation already in cache" do
      {:ok, anim} = Doodle.create_animation(%{x1: 0, y1: 0, x2: 50, y2: 50})
      CanvasServer.upsert_animation(anim, %{})

      {:ok, updated} = Doodle.update_animation(anim, %{frame_count: 4})
      CanvasServer.upsert_animation(updated, %{0 => [%{x: 1, y: 1, color: "#FF0000"}]})

      [a] = CanvasServer.get_animations()
      assert a.frame_count == 4
    end

    test "replaces frames for existing animation" do
      {:ok, anim} = Doodle.create_animation(%{x1: 0, y1: 0, x2: 50, y2: 50})
      CanvasServer.upsert_animation(anim, %{0 => [%{x: 1, y: 1, color: "#FF0000"}]})
      CanvasServer.upsert_animation(anim, %{0 => [%{x: 2, y: 2, color: "#0000FF"}]})

      [a] = CanvasServer.get_animations()
      assert a.frames == %{0 => [%{x: 2, y: 2, color: "#0000FF"}]}
    end
  end

  describe "remove_animation/1" do
    test "removes animation and its frames from cache" do
      {:ok, anim} = Doodle.create_animation(%{x1: 0, y1: 0, x2: 50, y2: 50})
      CanvasServer.upsert_animation(anim, %{0 => [%{x: 1, y: 1, color: "#FF0000"}]})
      assert length(CanvasServer.get_animations()) == 1

      CanvasServer.remove_animation(anim.id)
      assert CanvasServer.get_animations() == []
    end

    test "leaves other animations intact" do
      {:ok, anim_a} = Doodle.create_animation(%{x1: 0, y1: 0, x2: 50, y2: 50})
      {:ok, anim_b} = Doodle.create_animation(%{x1: 100, y1: 100, x2: 150, y2: 150})
      CanvasServer.upsert_animation(anim_a, %{})
      CanvasServer.upsert_animation(anim_b, %{})

      CanvasServer.remove_animation(anim_a.id)

      [remaining] = CanvasServer.get_animations()
      assert remaining.id == anim_b.id
    end

    test "no-op and no crash for unknown animation id" do
      CanvasServer.remove_animation(999_999)
      assert CanvasServer.get_animations() == []
    end
  end
end
