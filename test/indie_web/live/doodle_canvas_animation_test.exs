defmodule IndieWeb.DoodleCanvasAnimationTest do
  use IndieWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "create_animation event" do
    test "creates animation and returns id", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view
      |> element("#doodle-canvas")
      |> render_hook("create_animation", %{
        "x1" => 10,
        "y1" => 10,
        "x2" => 110,
        "y2" => 110
      })

      animations = Indie.Doodle.list_animations()
      assert length(animations) == 1
      assert hd(animations).x1 == 10
    end

    test "rejects region larger than 200x200", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view
      |> element("#doodle-canvas")
      |> render_hook("create_animation", %{
        "x1" => 0,
        "y1" => 0,
        "x2" => 500,
        "y2" => 500
      })

      assert Indie.Doodle.list_animations() == []
    end
  end

  describe "save_animation event" do
    test "saves frames and updates frame_count", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view
      |> element("#doodle-canvas")
      |> render_hook("create_animation", %{
        "x1" => 0,
        "y1" => 0,
        "x2" => 50,
        "y2" => 50
      })

      [anim] = Indie.Doodle.list_animations()

      view
      |> element("#doodle-canvas")
      |> render_hook("save_animation", %{
        "animation_id" => anim.id,
        "frames" => [
          %{"frame" => 0, "pixels" => [%{"x" => 5, "y" => 5, "color" => "#FF0000"}]},
          %{"frame" => 1, "pixels" => [%{"x" => 5, "y" => 5, "color" => "#0000FF"}]}
        ]
      })

      updated = Indie.Doodle.get_animation!(anim.id)
      assert updated.frame_count == 2

      by_frame = Indie.Doodle.get_animation_pixels(anim.id)
      assert map_size(by_frame) == 2
    end
  end
end
