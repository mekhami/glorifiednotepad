defmodule Indie.Doodle.SeedLogoTest do
  use Indie.DataCase

  alias Indie.Doodle.{CanvasServer, Pixel, SeedLogo}

  setup do
    CanvasServer.reload()
    :ok
  end

  test "pixels/0 stays inside the canvas and never uses the eraser color" do
    pixels = SeedLogo.pixels()

    assert map_size(pixels) > 0

    for {{x, y}, color} <- pixels do
      assert x in 0..1919 and y in 0..1079
      assert color =~ ~r/^#[0-9a-f]{6}$/
      refute color == "#df9390"
    end
  end

  test "run/0 writes the logo and the canvas cache shows it immediately" do
    expected = SeedLogo.pixels()

    assert {:ok, count} = SeedLogo.run()
    assert count == map_size(expected)
    assert Repo.aggregate(Pixel, :count) == map_size(expected)

    cached = Map.new(CanvasServer.get_pixels(), &{{&1.x, &1.y}, &1.color})
    assert Map.take(cached, Map.keys(expected)) == expected
  end

  test "run/0 repaints pixels drawn over the logo and leaves other pixels alone" do
    {{lx, ly}, logo_color} = Enum.at(SeedLogo.pixels(), 0)

    Repo.insert!(%Pixel{x: lx, y: ly, color: "#000000"})
    Repo.insert!(%Pixel{x: 0, y: 0, color: "#123456"})

    assert {:ok, _} = SeedLogo.run()
    assert {:ok, _} = SeedLogo.run()

    assert Repo.get_by!(Pixel, x: lx, y: ly).color == logo_color
    assert Repo.get_by!(Pixel, x: 0, y: 0).color == "#123456"
    assert Repo.aggregate(Pixel, :count) == map_size(SeedLogo.pixels()) + 1
  end
end
