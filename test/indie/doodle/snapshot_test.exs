defmodule Indie.Doodle.SnapshotTest do
  use ExUnit.Case, async: true

  alias Indie.Doodle.Snapshot

  @row_bytes 1 + 1920 * 4

  defp decode(png) do
    <<137, 80, 78, 71, 13, 10, 26, 10, rest::binary>> = png
    chunks = chunks(rest, [])
    {"IHDR", <<w::32, h::32, 8, 6, 0, 0, 0>>} = List.keyfind(chunks, "IHDR", 0)

    raw =
      chunks
      |> Enum.filter(&match?({"IDAT", _}, &1))
      |> Enum.map(&elem(&1, 1))
      |> IO.iodata_to_binary()
      |> :zlib.uncompress()

    {w, h, raw}
  end

  defp chunks(<<>>, acc), do: Enum.reverse(acc)

  defp chunks(<<len::32, type::binary-4, data::binary-size(len), crc::32, rest::binary>>, acc) do
    assert :erlang.crc32([type, data]) == crc
    chunks(rest, [{type, data} | acc])
  end

  defp pixel(raw, x, y) do
    offset = y * @row_bytes + 1 + x * 4
    <<_::binary-size(offset), rgba::binary-4, _::binary>> = raw
    rgba
  end

  test "is a 1920x1080 RGBA image with valid chunk checksums" do
    {w, h, raw} = Snapshot.build([], []) |> decode()
    assert {w, h} == {1920, 1080}
    assert byte_size(raw) == 1080 * @row_bytes
  end

  test "draws static pixels and leaves everything else transparent" do
    {_, _, raw} = Snapshot.build([%{x: 10, y: 20, color: "#FF0000"}], []) |> decode()
    assert pixel(raw, 10, 20) == <<255, 0, 0, 255>>
    assert pixel(raw, 0, 0) == <<0, 0, 0, 0>>
    assert pixel(raw, 1919, 1079) == <<0, 0, 0, 0>>
  end

  test "animation frame 0 draws over a static pixel and later frames are ignored" do
    pixels = [%{x: 5, y: 5, color: "#FF0000"}]

    animations = [
      %{
        frames: %{
          0 => [%{x: 5, y: 5, color: "#0000FF"}],
          1 => [%{x: 6, y: 6, color: "#00FF00"}]
        }
      }
    ]

    {_, _, raw} = Snapshot.build(pixels, animations) |> decode()
    assert pixel(raw, 5, 5) == <<0, 0, 255, 255>>
    assert pixel(raw, 6, 6) == <<0, 0, 0, 0>>
  end

  test "pixels outside the board are ignored" do
    pixels = [%{x: 1920, y: 0, color: "#FF0000"}, %{x: 0, y: -1, color: "#FF0000"}]
    {_, _, raw} = Snapshot.build(pixels, []) |> decode()
    assert pixel(raw, 0, 0) == <<0, 0, 0, 0>>
  end

  test "edge pixels land in the right cells" do
    pixels = [%{x: 0, y: 0, color: "#010203"}, %{x: 1919, y: 1079, color: "#040506"}]
    {_, _, raw} = Snapshot.build(pixels, []) |> decode()
    assert pixel(raw, 0, 0) == <<1, 2, 3, 255>>
    assert pixel(raw, 1919, 1079) == <<4, 5, 6, 255>>
  end

  test "output does not depend on input order" do
    pixels = for x <- 0..50, y <- 0..5, do: %{x: x, y: y, color: "#A0B0C0"}
    assert Snapshot.build(pixels, []) == Snapshot.build(Enum.shuffle(pixels), [])
  end
end
