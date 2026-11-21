defmodule Indie.Doodle.Snapshot do
  @moduledoc """
  Composes the doodle board into a lossless 1920x1080 RGBA PNG.

  Static pixels are drawn first, then frame 0 of every animation on top. That
  matches what the canvas hook shows right after `load-animations`.
  """

  @width 1920
  @height 1080
  @signature <<137, 80, 78, 71, 13, 10, 26, 10>>
  @blank_pixel <<0, 0, 0, 0>>
  @blank_row <<0, :binary.copy(@blank_pixel, @width)::binary>>

  def build(pixels, animations) do
    pixels
    |> composite(animations)
    |> rows()
    |> encode()
  end

  defp composite(pixels, animations) do
    base = Map.new(pixels, fn %{x: x, y: y, color: color} -> {{y, x}, color} end)

    animations
    |> Enum.flat_map(fn animation -> Map.get(animation.frames, 0, []) end)
    |> Enum.reduce(base, fn %{x: x, y: y, color: color}, acc -> Map.put(acc, {y, x}, color) end)
    |> Enum.filter(fn {{y, x}, _} -> x >= 0 and x < @width and y >= 0 and y < @height end)
    |> Enum.sort()
  end

  defp rows(cells) do
    by_row =
      cells
      |> Enum.chunk_by(fn {{y, _x}, _color} -> y end)
      |> Map.new(fn [{{y, _x}, _color} | _] = row_cells -> {y, row(row_cells)} end)

    for y <- 0..(@height - 1), do: Map.get(by_row, y, @blank_row)
  end

  defp row(cells) do
    {iodata, next_x} =
      Enum.reduce(cells, {[0], 0}, fn {{_y, x}, color}, {acc, current_x} ->
        gap = :binary.copy(@blank_pixel, x - current_x)
        {[acc, gap, rgba(color)], x + 1}
      end)

    [iodata, :binary.copy(@blank_pixel, @width - next_x)]
  end

  defp rgba("#" <> <<r::binary-2, g::binary-2, b::binary-2>>) do
    <<String.to_integer(r, 16), String.to_integer(g, 16), String.to_integer(b, 16), 255>>
  end

  defp encode(rows) do
    ihdr = <<@width::32, @height::32, 8, 6, 0, 0, 0>>

    IO.iodata_to_binary([
      @signature,
      chunk("IHDR", ihdr),
      chunk("IDAT", :zlib.compress(rows)),
      chunk("IEND", <<>>)
    ])
  end

  defp chunk(type, data) do
    data = IO.iodata_to_binary(data)
    [<<byte_size(data)::32>>, type, data, <<:erlang.crc32([type, data])::32>>]
  end
end
