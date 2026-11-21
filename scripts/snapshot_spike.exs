dir = System.get_env("SPIKE_DIR") || System.tmp_dir!()
board = dir |> Path.join("board.json") |> File.read!() |> Jason.decode!()

pixels =
  Enum.map(board["pixels"], fn p -> %{x: p["x"], y: p["y"], color: p["color"]} end)

animations =
  Enum.map(board["animations"], fn a ->
    frames =
      Map.new(a["frames"], fn {idx, ps} ->
        {String.to_integer(idx),
         Enum.map(ps, fn p -> %{x: p["x"], y: p["y"], color: p["color"]} end)}
      end)

    %{frames: frames}
  end)

times =
  for _ <- 1..5 do
    {us, png} = :timer.tc(fn -> Indie.Doodle.Snapshot.build(pixels, animations) end)
    {us / 1000, png}
  end

sorted = times |> Enum.map(&elem(&1, 0)) |> Enum.sort()
{_, png} = hd(times)
File.write!(Path.join(dir, "board.png"), png)

IO.inspect(%{
  png_bytes: byte_size(png),
  build_ms_median: Enum.at(sorted, 2),
  build_ms_range: {hd(sorted), List.last(sorted)}
})
