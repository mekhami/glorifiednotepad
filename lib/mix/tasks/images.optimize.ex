defmodule Mix.Tasks.Images.Optimize do
  @moduledoc """
  Optimizes images in priv/static/images/ using available tools.

  ## Usage

      mix images.optimize

  This task will:
  - Find all .jpg, .jpeg, .png, and .webp files in priv/static/images/
  - Optimize them losslessly using jpegoptim, oxipng, and cwebp
  - Report size savings
  - Skip already-optimized images (idempotent)

  ## Required System Dependencies

  - jpegoptim (for JPEG optimization)
  - oxipng or optipng (for PNG optimization, oxipng is faster but requires cargo)
  - webp (for WebP optimization, includes cwebp tool)

  Install on Ubuntu/Debian:

      sudo apt install jpegoptim optipng webp

  For better PNG optimization, install oxipng via cargo:

      cargo install oxipng

  """

  use Mix.Task

  @images_dir "priv/static/images"
  @optimized_marker ".optimized"

  @shortdoc "Optimizes images in priv/static/images/"

  def run(_args) do
    Mix.shell().info("🖼️  Optimizing images in #{@images_dir}...")

    unless File.dir?(@images_dir) do
      Mix.shell().info("✓ No images directory found at #{@images_dir}, skipping optimization")
      :ok
    else
      {jpeg_count, jpeg_savings} = optimize_jpegs()
      {png_count, png_savings} = optimize_pngs()
      {webp_count, webp_savings} = optimize_webps()

      total_count = jpeg_count + png_count + webp_count
      total_savings = jpeg_savings + png_savings + webp_savings

      if total_count > 0 do
        Mix.shell().info("\n✓ Optimized #{total_count} images")
        Mix.shell().info("  Saved #{format_bytes(total_savings)} total")
      else
        Mix.shell().info("✓ All images already optimized")
      end
    end
  end

  defp optimize_jpegs do
    jpeg_files =
      Path.wildcard("#{@images_dir}/**/*.{jpg,jpeg}", match_dot: false)

    if Enum.empty?(jpeg_files) do
      {0, 0}
    else
      case System.find_executable("jpegoptim") do
        nil ->
          Mix.shell().error("⚠️  jpegoptim not found. Install with: sudo apt install jpegoptim")

          {0, 0}

        jpegoptim ->
          jpeg_files
          |> Enum.reject(&already_optimized?/1)
          |> Enum.reduce({0, 0}, fn file, {count, savings} ->
            case optimize_jpeg(jpegoptim, file) do
              {:ok, saved} ->
                mark_optimized(file)
                {count + 1, savings + saved}

              {:error, _} ->
                {count, savings}
            end
          end)
      end
    end
  end

  defp optimize_pngs do
    png_files = Path.wildcard("#{@images_dir}/**/*.png", match_dot: false)

    if Enum.empty?(png_files) do
      {0, 0}
    else
      # Try oxipng first, fallback to optipng
      png_tool = System.find_executable("oxipng") || System.find_executable("optipng")

      case png_tool do
        nil ->
          Mix.shell().error(
            "⚠️  PNG optimizer not found. Install with: sudo apt install optipng"
          )

          {0, 0}

        tool ->
          png_files
          |> Enum.reject(&already_optimized?/1)
          |> Enum.reduce({0, 0}, fn file, {count, savings} ->
            case optimize_png(tool, file) do
              {:ok, saved} ->
                mark_optimized(file)
                {count + 1, savings + saved}

              {:error, _} ->
                {count, savings}
            end
          end)
      end
    end
  end

  defp optimize_webps do
    webp_files = Path.wildcard("#{@images_dir}/**/*.webp", match_dot: false)

    if Enum.empty?(webp_files) do
      {0, 0}
    else
      case System.find_executable("cwebp") do
        nil ->
          Mix.shell().error("⚠️  cwebp not found. Install with: sudo apt install webp")
          {0, 0}

        cwebp ->
          webp_files
          |> Enum.reject(&already_optimized?/1)
          |> Enum.reduce({0, 0}, fn file, {count, savings} ->
            case optimize_webp(cwebp, file) do
              {:ok, saved} ->
                mark_optimized(file)
                {count + 1, savings + saved}

              {:error, _} ->
                {count, savings}
            end
          end)
      end
    end
  end

  defp optimize_jpeg(jpegoptim, file) do
    size_before = File.stat!(file).size

    # Run jpegoptim with --strip-all (remove metadata) and lossless optimization
    case System.cmd(jpegoptim, ["--strip-all", "--quiet", file]) do
      {_, 0} ->
        size_after = File.stat!(file).size
        saved = size_before - size_after

        if saved > 0 do
          Mix.shell().info("  ✓ #{Path.basename(file)}: saved #{format_bytes(saved)}")
        end

        {:ok, max(saved, 0)}

      {output, _} ->
        Mix.shell().error("  ✗ Failed to optimize #{Path.basename(file)}: #{output}")
        {:error, output}
    end
  end

  defp optimize_png(png_tool, file) do
    size_before = File.stat!(file).size

    # Detect which tool we're using and adjust arguments
    args =
      cond do
        String.ends_with?(png_tool, "oxipng") ->
          ["--opt", "2", "--strip", "safe", "--quiet", file]

        String.ends_with?(png_tool, "optipng") ->
          ["-o2", "-strip", "all", "-quiet", file]

        true ->
          # Default to oxipng args
          ["--opt", "2", "--strip", "safe", "--quiet", file]
      end

    case System.cmd(png_tool, args) do
      {_, 0} ->
        size_after = File.stat!(file).size
        saved = size_before - size_after

        if saved > 0 do
          Mix.shell().info("  ✓ #{Path.basename(file)}: saved #{format_bytes(saved)}")
        end

        {:ok, max(saved, 0)}

      {output, _} ->
        Mix.shell().error("  ✗ Failed to optimize #{Path.basename(file)}: #{output}")
        {:error, output}
    end
  end

  defp optimize_webp(cwebp, file) do
    size_before = File.stat!(file).size

    # Create a temporary output file
    temp_file = file <> ".tmp"

    # Run cwebp with lossless compression (-lossless) and quality level 75
    # We need to output to a temp file then replace the original
    case System.cmd(cwebp, ["-lossless", "-q", "75", file, "-o", temp_file]) do
      {_, 0} ->
        size_after = File.stat!(temp_file).size
        saved = size_before - size_after

        if saved > 0 do
          # Replace original with optimized version
          File.rename!(temp_file, file)
          Mix.shell().info("  ✓ #{Path.basename(file)}: saved #{format_bytes(saved)}")
          {:ok, max(saved, 0)}
        else
          # Keep original if it's already optimal
          File.rm!(temp_file)
          {:ok, 0}
        end

      {output, _} ->
        # Clean up temp file if it exists
        if File.exists?(temp_file), do: File.rm!(temp_file)
        Mix.shell().error("  ✗ Failed to optimize #{Path.basename(file)}: #{output}")
        {:error, output}
    end
  end

  defp already_optimized?(file) do
    marker_file = file <> @optimized_marker
    File.exists?(marker_file) && File.stat!(marker_file).mtime >= File.stat!(file).mtime
  end

  defp mark_optimized(file) do
    marker_file = file <> @optimized_marker
    File.write!(marker_file, "")
  end

  defp format_bytes(bytes) when bytes >= 1_048_576 do
    "#{Float.round(bytes / 1_048_576, 2)} MB"
  end

  defp format_bytes(bytes) when bytes >= 1024 do
    "#{Float.round(bytes / 1024, 2)} KB"
  end

  defp format_bytes(bytes) do
    "#{bytes} bytes"
  end
end
