defmodule Indie.Doodle.SeedLogo do
  @moduledoc """
  Paints the "glorified notepad" pixel-art logo onto the doodle canvas.

  Only logo pixels are written; surrounding pixels are left alone. Safe to run
  repeatedly — it just repaints anything drawn over the logo.

  Run on demand against the live app with `./ops.sh seed-logo`; runs daily via
  `Indie.Doodle.LogoScheduler`.

  Tweak `@y_center` if the logo position is off. At default zoom (scale=2.0):
    ~900px viewport  → top of screen ≈ y=428, first post ≈ y=460
    ~1080px viewport → top of screen ≈ y=405, first post ≈ y=437
  Body has 11rem (176px) of top padding — the logo should land in that gap.
  """

  require Logger

  alias Indie.Doodle.{CanvasServer, Pixel}
  alias Indie.Repo

  @y_center 440
  @x_center 960
  @dot 2
  @pad_dots 2
  @bord_dots 1

  @canvas_w 1920
  @canvas_h 1080
  @eraser "#df9390"

  @text "glorified notepad"
  @char_w 5
  @char_h 7
  @gap 1

  @font %{
    " " => ~w(00000 00000 00000 00000 00000 00000 00000),
    "a" => ~w(00000 00000 01110 00001 01111 10001 01111),
    "d" => ~w(00001 00001 01111 10001 10001 10001 01111),
    "e" => ~w(00000 00000 01110 10001 11110 10000 01110),
    "f" => ~w(00110 01000 01000 11110 01000 01000 01000),
    "g" => ~w(01110 10001 10001 01111 00001 10001 01110),
    "i" => ~w(00100 00000 00100 00100 00100 00100 01110),
    "l" => ~w(01100 00100 00100 00100 00100 00100 01110),
    "n" => ~w(00000 00000 10110 11001 10001 10001 10001),
    "o" => ~w(00000 00000 01110 10001 10001 10001 01110),
    "p" => ~w(00000 01110 10001 10001 11110 10000 10000),
    "r" => ~w(00000 00000 10110 11000 10000 10000 10000),
    "t" => ~w(00100 00100 01111 00100 00100 00100 00110)
  }

  @border_palette ~w(#ff3333 #ff9933 #ffff33 #44ee44 #33ddff #5566ff #cc44ff)
  @sparkle_colors ~w(#ff0088 #ffee00 #00ffcc #ff6600 #88ff00 #ff00ff #00ccff #ff4444)

  # Postgres allows 65535 bind params; 5 columns per row.
  @chunk_size 6000

  @doc "Upserts the logo pixels and refreshes the canvas cache."
  def run do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    rows =
      Enum.map(pixels(), fn {{x, y}, color} ->
        %{x: x, y: y, color: color, inserted_at: now, updated_at: now}
      end)

    count =
      rows
      |> Enum.chunk_every(@chunk_size)
      |> Enum.reduce(0, fn chunk, acc ->
        {n, _} =
          Repo.insert_all(Pixel, chunk,
            on_conflict: {:replace, [:color, :updated_at]},
            conflict_target: {:unsafe_fragment, "(x, y) WHERE animation_id IS NULL"}
          )

        acc + n
      end)

    if Process.whereis(CanvasServer), do: CanvasServer.reload()

    Logger.info("SeedLogo: wrote #{count} logo pixels")
    {:ok, count}
  end

  @doc "Returns the logo as a map of `{x, y} => color`."
  def pixels do
    text_grid_w = (String.length(@text) * (@char_w + @gap) - @gap) * @dot
    text_grid_h = @char_h * @dot
    text_x = @x_center - div(text_grid_w, 2)
    text_y = @y_center - div(text_grid_h, 2)

    pad = @pad_dots * @dot
    bord = @bord_dots * @dot

    inner =
      {text_x - pad, text_y - pad, text_x + text_grid_w - 1 + pad, text_y + text_grid_h - 1 + pad}

    {ix1, iy1, ix2, iy2} = inner
    border = {ix1 - bord, iy1 - bord, ix2 + bord, iy2 + bord}

    (fill_pixels(inner) ++
       border_pixels(border, inner) ++
       sparkle_pixels(border) ++
       text_pixels(text_x, text_y))
    |> Enum.reduce(%{}, fn {x, y, color}, acc -> Map.put(acc, {x, y}, color) end)
    |> Map.reject(fn {{x, y}, color} ->
      x < 0 or x >= @canvas_w or y < 0 or y >= @canvas_h or color == @eraser
    end)
  end

  defp fill_pixels({x1, y1, x2, y2}) do
    for x <- x1..x2, y <- y1..y2, do: {x, y, "#1a1a2e"}
  end

  defp border_pixels({bx1, by1, bx2, by2}, {ix1, iy1, ix2, iy2}) do
    for x <- bx1..bx2,
        y <- by1..by2,
        not (x >= ix1 and x <= ix2 and y >= iy1 and y <= iy2) do
      idx = rem(div(x + y, 6), length(@border_palette))
      {x, y, Enum.at(@border_palette, idx)}
    end
  end

  defp text_pixels(text_x, text_y) do
    dots =
      for {ch, ci} <- Enum.with_index(String.graphemes(@text)),
          rows = Map.get(@font, ch, @font[" "]),
          {row_str, row} <- Enum.with_index(rows),
          {bit, col} <- Enum.with_index(String.graphemes(row_str)),
          bit == "1",
          dx <- 0..(@dot - 1),
          dy <- 0..(@dot - 1) do
        {text_x + (ci * (@char_w + @gap) + col) * @dot + dx, text_y + row * @dot + dy}
      end

    {min_x, max_x} = dots |> Enum.map(&elem(&1, 0)) |> Enum.min_max()
    {min_y, max_y} = dots |> Enum.map(&elem(&1, 1)) |> Enum.min_max()
    diag = max_x - min_x + (max_y - min_y)

    Enum.map(dots, fn {x, y} ->
      t = if diag == 0, do: 0.0, else: (x - min_x + (y - min_y)) / diag
      {x, y, neon_lerp(t)}
    end)
  end

  defp sparkle_pixels({bx1, by1, bx2, by2}) do
    mid_x = div(bx1 + bx2, 2)
    mid_y = div(by1 + by2, 2)
    qx = div(bx2 - bx1, 4)

    specs = [
      {bx1 - 3 * @dot, by1 - 3 * @dot, 2 * @dot, 0},
      {bx2 + 3 * @dot, by1 - 3 * @dot, 2 * @dot, 1},
      {bx1 - 3 * @dot, by2 + 3 * @dot, 2 * @dot, 2},
      {bx2 + 3 * @dot, by2 + 3 * @dot, 2 * @dot, 3},
      {bx1 + qx, by1 - 4 * @dot, @dot, 4},
      {bx1 + qx * 3, by1 - 4 * @dot, @dot, 5},
      {bx1 + qx, by2 + 4 * @dot, @dot, 6},
      {bx1 + qx * 3, by2 + 4 * @dot, @dot, 7},
      {bx1 - 4 * @dot, mid_y, @dot, 0},
      {bx2 + 4 * @dot, mid_y, @dot, 1},
      {mid_x, by1 - 5 * @dot, @dot, 2},
      {mid_x, by2 + 5 * @dot, @dot, 3}
    ]

    for {cx, cy, reach, color_idx} <- specs,
        color = Enum.at(@sparkle_colors, rem(color_idx, length(@sparkle_colors))),
        i <- -reach..reach,
        point <- [{cx + i, cy}, {cx, cy + i}] do
      {x, y} = point
      {x, y, color}
    end
  end

  defp neon_lerp(t) do
    # lime #22c55e → purple #a21caf
    r = round(0x22 + (0xA2 - 0x22) * t)
    g = round(0xC5 + (0x1C - 0xC5) * t)
    b = round(0x5E + (0xAF - 0x5E) * t)
    "#" <> hex2(r) <> hex2(g) <> hex2(b)
  end

  defp hex2(v), do: v |> Integer.to_string(16) |> String.downcase() |> String.pad_leading(2, "0")
end
