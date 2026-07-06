# Inserts the "glorified notepad" pixel art logo into the doodle canvas.
#
# Run with:   mix run priv/scripts/seed_logo.exs
# Re-run any time the logo gets drawn over.
#
# Tweak y_center if the logo position is off on your screen.
# At default zoom (scale=2.0) the visible grid rows depend on viewport height:
#   ~900px viewport  → top of screen ≈ y=428, first post ≈ y=460
#   ~1080px viewport → top of screen ≈ y=405, first post ≈ y=437
# Body has 11rem (176px) of top padding — logo should land in that gap.

# Start only the repo — don't start the full app (HTTP endpoint conflicts with
# the running service which already owns the port).
Application.ensure_all_started(:ecto_sql)
Application.ensure_all_started(:ecto_sqlite3)
{:ok, _} = Indie.Repo.start_link([])

alias Indie.Repo
alias Indie.Doodle.Pixel

# ── Configuration (tweak these) ───────────────────────────────────────────────

y_center  = 440   # vertical center of logo in grid units — adjust to taste
x_center  = 960   # horizontal center (960 = always viewport center)
dot       = 2     # each font "dot" = this many grid units (matches canvas PIXEL_SIZE)
pad_dots  = 2     # padding inside the box (in dots)
bord_dots = 1     # border thickness (in dots)

# ── Font bitmaps (5 wide × 7 tall) ───────────────────────────────────────────

font = %{
  " " => ["00000","00000","00000","00000","00000","00000","00000"],
  "a" => ["00000","00000","01110","00001","01111","10001","01111"],
  "d" => ["00001","00001","01111","10001","10001","10001","01111"],
  "e" => ["00000","00000","01110","10001","11110","10000","01110"],
  "f" => ["00110","01000","01000","11110","01000","01000","01000"],
  "g" => ["01110","10001","10001","01111","00001","10001","01110"],
  "i" => ["00100","00000","00100","00100","00100","00100","01110"],
  "l" => ["01100","00100","00100","00100","00100","00100","01110"],
  "n" => ["00000","00000","10110","11001","10001","10001","10001"],
  "o" => ["00000","00000","01110","10001","10001","10001","01110"],
  "p" => ["00000","01110","10001","10001","11110","10000","10000"],
  "r" => ["00000","00000","10110","11000","10000","10000","10000"],
  "t" => ["00100","00100","01111","00100","00100","00100","00110"],
}

text   = "glorified notepad"
char_w = 5
char_h = 7
gap    = 1

# ── Layout ────────────────────────────────────────────────────────────────────

text_dots_w = String.length(text) * (char_w + gap) - gap   # 101 dots
text_grid_w = text_dots_w * dot                             # 202 grid units
text_grid_h = char_h * dot                                  # 14 grid units
text_x      = x_center - div(text_grid_w, 2)               # top-left x of text
text_y      = y_center - div(text_grid_h, 2)               # top-left y of text

pad_grid  = pad_dots * dot
bord_grid = bord_dots * dot

inner_x1 = text_x - pad_grid
inner_y1 = text_y - pad_grid
inner_x2 = text_x + text_grid_w - 1 + pad_grid
inner_y2 = text_y + text_grid_h - 1 + pad_grid

border_x1 = inner_x1 - bord_grid
border_y1 = inner_y1 - bord_grid
border_x2 = inner_x2 + bord_grid
border_y2 = inner_y2 + bord_grid

IO.puts("Box grid bounds: (#{border_x1},#{border_y1}) → (#{border_x2},#{border_y2})")
IO.puts("Text starts at: (#{text_x}, #{text_y})")

# ── Color helpers ─────────────────────────────────────────────────────────────

hex2 = fn v ->
  v |> Integer.to_string(16) |> String.downcase() |> String.pad_leading(2, "0")
end

neon_lerp = fn t ->
  # lime #22c55e → purple #a21caf
  r = round(0x22 + (0xa2 - 0x22) * t)
  g = round(0xc5 + (0x1c - 0xc5) * t)
  b = round(0x5e + (0xaf - 0x5e) * t)
  "##{hex2.(r)}#{hex2.(g)}#{hex2.(b)}"
end

border_palette = ~w[#ff3333 #ff9933 #ffff33 #44ee44 #33ddff #5566ff #cc44ff]

border_color = fn x, y ->
  # diagonal stripes cycling through palette; every 6 grid units = one color block
  idx = rem(div(x + y, 6), length(border_palette))
  Enum.at(border_palette, idx)
end

sparkle_colors = ~w[#ff0088 #ffee00 #00ffcc #ff6600 #88ff00 #ff00ff #00ccff #ff4444]

# ── 1. Box fill ───────────────────────────────────────────────────────────────

fill_pixels =
  for x <- inner_x1..inner_x2, y <- inner_y1..inner_y2 do
    {x, y, "#1a1a2e"}
  end

# ── 2. Rainbow border ─────────────────────────────────────────────────────────

border_pixels =
  for x <- border_x1..border_x2,
      y <- border_y1..border_y2,
      not (x >= inner_x1 and x <= inner_x2 and y >= inner_y1 and y <= inner_y2) do
    {x, y, border_color.(x, y)}
  end

# ── 3. Text (neon diagonal gradient, each dot = dot×dot grid block) ───────────

raw_text_dots =
  for {ch, ci} <- Enum.with_index(String.graphemes(text)),
      rows = Map.get(font, ch, font[" "]),
      {row_str, row} <- Enum.with_index(rows),
      {bit, col} <- Enum.with_index(String.graphemes(row_str)),
      bit == "1" do
    base_x = text_x + (ci * (char_w + gap) + col) * dot
    base_y = text_y + row * dot
    for dx <- 0..(dot - 1), dy <- 0..(dot - 1), do: {base_x + dx, base_y + dy}
  end
  |> List.flatten()

{min_tx, max_tx} = Enum.min_max(Enum.map(raw_text_dots, fn {x, _} -> x end))
{min_ty, max_ty} = Enum.min_max(Enum.map(raw_text_dots, fn {_, y} -> y end))
diag = (max_tx - min_tx) + (max_ty - min_ty)

text_pixels =
  Enum.map(raw_text_dots, fn {x, y} ->
    t = if diag == 0, do: 0.0, else: ((x - min_tx) + (y - min_ty)) / diag
    {x, y, neon_lerp.(t)}
  end)

# ── 4. Sparkles (+ crosses outside the box) ───────────────────────────────────

cross = fn cx, cy, reach, color ->
  for i <- -reach..reach do
    [{cx + i, cy, color}, {cx, cy + i, color}]
  end
  |> List.flatten()
end

mid_x = div(border_x1 + border_x2, 2)
mid_y = div(border_y1 + border_y2, 2)
qx    = div(border_x2 - border_x1, 4)

sparkle_specs = [
  # corners — bigger (reach = 2*dot)
  {border_x1 - 3 * dot, border_y1 - 3 * dot, 2 * dot, 0},
  {border_x2 + 3 * dot, border_y1 - 3 * dot, 2 * dot, 1},
  {border_x1 - 3 * dot, border_y2 + 3 * dot, 2 * dot, 2},
  {border_x2 + 3 * dot, border_y2 + 3 * dot, 2 * dot, 3},
  # top edge
  {border_x1 + qx,      border_y1 - 4 * dot, dot,     4},
  {border_x1 + qx * 3,  border_y1 - 4 * dot, dot,     5},
  # bottom edge
  {border_x1 + qx,      border_y2 + 4 * dot, dot,     6},
  {border_x1 + qx * 3,  border_y2 + 4 * dot, dot,     7},
  # sides
  {border_x1 - 4 * dot, mid_y,               dot,     0},
  {border_x2 + 4 * dot, mid_y,               dot,     1},
  # center top/bottom
  {mid_x,               border_y1 - 5 * dot, dot,     2},
  {mid_x,               border_y2 + 5 * dot, dot,     3},
]

sparkle_pixels =
  Enum.flat_map(sparkle_specs, fn {cx, cy, reach, color_idx} ->
    color = Enum.at(sparkle_colors, rem(color_idx, length(sparkle_colors)))
    cross.(cx, cy, reach, color)
  end)

# ── Merge: fill → border → sparkles → text (text wins conflicts) ──────────────

all_pixels = fill_pixels ++ border_pixels ++ sparkle_pixels ++ text_pixels

pixel_map =
  Enum.reduce(all_pixels, %{}, fn {x, y, color}, acc ->
    Map.put(acc, {x, y}, color)
  end)

# Filter out eraser color and out-of-bounds
eraser = "#df9390"
pixel_map =
  Map.reject(pixel_map, fn {{x, y}, color} ->
    x < 0 or x >= 1920 or y < 0 or y >= 1080 or color == eraser
  end)

# ── Upsert ────────────────────────────────────────────────────────────────────
# Only write logo pixels — do NOT delete the surrounding region.
# Deleting the bounding box leaves transparent gaps that show the salmon
# page background, making it look like salmon pixels were added.

now = DateTime.utc_now() |> DateTime.truncate(:second)

rows =
  Enum.map(pixel_map, fn {{x, y}, color} ->
    %{x: x, y: y, color: color, inserted_at: now, updated_at: now}
  end)

IO.puts("Upserting #{length(rows)} pixels...")

# SQLite limit: max 32766 bind params per query; each row uses 5 columns → 6553 rows/batch
chunk_size = 6000

count =
  rows
  |> Enum.chunk_every(chunk_size)
  |> Enum.reduce(0, fn chunk, acc ->
    {n, _} =
      Repo.insert_all(
        Pixel,
        chunk,
        on_conflict: {:replace, [:color, :updated_at]},
        conflict_target: {:unsafe_fragment, "(x, y) WHERE animation_id IS NULL"}
      )
    acc + n
  end)

IO.puts("Done. #{count} pixels written.")
IO.puts("")
IO.puts("If it's in the wrong vertical position, change y_center (currently #{y_center}) and re-run.")
