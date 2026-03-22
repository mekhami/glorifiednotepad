defmodule IndieWeb.Pixels do
  @moduledoc """
  Utilities for generating deterministic pixel colors for posts.
  """

  @doc """
  Generates a deterministic list of pixel colors based on a post ID.

  Uses seeded randomization to ensure the same post ID always produces
  the same sequence of colors, allowing consistent pixel strips across
  page loads and different views.

  ## Parameters

    * `post_id` - The unique identifier for the post
    * `count` - Number of pixel colors to generate (default: 18)

  ## Returns

  A list of hex color strings (e.g., `["#FF00FF", "#00FFFF", ...]`)

  ## Examples

      iex> IndieWeb.Pixels.generate_pixel_colors("my-post-slug")
      ["#FF00FF", "#00FFFF", ...]

      iex> IndieWeb.Pixels.generate_pixel_colors("my-post-slug", 5)
      ["#FF00FF", "#00FFFF", "#FFFF00", "#FF6B6B", "#4ECDC4"]

  """
  def generate_pixel_colors(post_id, count \\ 18)

  def generate_pixel_colors(_post_id, 0), do: []

  def generate_pixel_colors(post_id, count) do
    seed = :erlang.phash2(post_id)

    # :exsss algorithm expects a 3-tuple seed
    rand_state = :rand.seed_s(:exsss, {seed, seed, seed})

    # Color palette matching rootring widget aesthetic
    colors = [
      "#FF00FF",
      "#00FFFF",
      "#FFFF00",
      "#FF6B6B",
      "#4ECDC4",
      "#95E1D3",
      "#F38181",
      "#AA96DA",
      "#FCBAD3",
      "#FFFFD2",
      "#A8E6CF",
      "#FFD3B6",
      "#FFAAA5",
      "#FF8B94",
      "#6C5CE7",
      "#FD79A8",
      "#FDCB6E",
      "#00B894"
    ]

    # Generate pixel colors using isolated state
    {pixel_colors, _final_state} =
      Enum.map_reduce(1..count, rand_state, fn _, state ->
        {random_idx, new_state} = :rand.uniform_s(length(colors), state)
        {Enum.at(colors, random_idx - 1), new_state}
      end)

    pixel_colors
  end
end
