defmodule Mix.Tasks.Images.Optimize do
  @moduledoc """
  Optimizes images in priv/static/images/ using available tools.

  ## Usage

      mix images.optimize

  This task will:
  - Find all .jpg, .jpeg, .png, and .webp files in priv/static/images/
  - Optimize PNGs with two passes: lossy quantization (pngquant) then lossless
    recompression (oxipng/optipng). The lossy pass can reduce complex or
    photographic PNGs by 70-90%; the lossless pass squeezes the remainder.
  - Optimize JPEGs losslessly using jpegoptim
  - Optimize WebP files losslessly using cwebp
  - Report size savings
  - Skip already-optimized images (idempotent via .optimized sidecar files)

  ## Persistent Cache

  Set `IMAGE_CACHE_PATH` to enable a persistent SHA256-based cache across deploys.
  The cache stores optimized image copies keyed by source SHA256. On subsequent
  runs, images whose source hash matches a cache entry are restored from the cache
  instead of re-optimized.

  ## Required System Dependencies

  - pngquant (for lossy PNG quantization - strongly recommended)
  - jpegoptim (for JPEG optimization)
  - oxipng or optipng (for lossless PNG recompression, oxipng preferred)
  - webp (for WebP optimization, includes cwebp tool)

  Install on macOS:

      brew install pngquant jpegoptim oxipng webp

  Install on Ubuntu/Debian:

      sudo apt install pngquant jpegoptim optipng webp

  For better PNG optimization, install oxipng via cargo:

      cargo install oxipng

  pngquant is optional but highly recommended. If missing, only lossless PNG
  optimization runs (much smaller savings for photographic or complex images).
  """

  use Mix.Task

  @images_dir "priv/static/images"
  @optimized_marker ".optimized"
  @cache_version "images-optimize-v1"
  @manifest_filename "manifest.json"

  @shortdoc "Optimizes images in priv/static/images/"

  def run(_args) do
    Mix.shell().info("Optimizing images in #{@images_dir}...")

    unless File.dir?(@images_dir) do
      Mix.shell().info("No images directory found at #{@images_dir}, skipping optimization")
      :ok
    else
      cache = load_cache()

      {jpeg_count, jpeg_savings, cache} = optimize_jpegs(cache)
      {png_count, png_savings, cache} = optimize_pngs(cache)
      {webp_count, webp_savings, cache} = optimize_webps(cache)

      persist_cache(cache)

      total_count = jpeg_count + png_count + webp_count
      total_savings = jpeg_savings + png_savings + webp_savings

      if total_count > 0 do
        Mix.shell().info("\nOptimized #{total_count} images")
        Mix.shell().info("  Saved #{format_bytes(total_savings)} total")
      else
        Mix.shell().info("All images already optimized")
      end
    end
  end

  defp load_cache do
    cache_path = cache_path()

    if is_nil(cache_path) do
      %{path: nil, manifest: nil}
    else
      manifest_file = Path.join(cache_path, @manifest_filename)

      manifest =
        case File.read(manifest_file) do
          {:ok, content} ->
            case Jason.decode(content) do
              {:ok, decoded} -> decoded
              _ -> default_manifest()
            end

          {:error, _} ->
            default_manifest()
        end

      %{path: cache_path, manifest: manifest}
    end
  end

  defp default_manifest do
    %{"version" => 1, "entries" => %{}}
  end

  defp persist_cache(%{path: nil}), do: :ok

  defp persist_cache(%{path: cache_path, manifest: manifest}) do
    File.mkdir_p!(cache_path)
    json = Jason.encode!(manifest)
    tmp_path = Path.join(cache_path, @manifest_filename <> ".tmp")
    final_path = Path.join(cache_path, @manifest_filename)
    File.write!(tmp_path, json)
    File.rename!(tmp_path, final_path)
  end

  defp cache_path do
    case System.get_env("IMAGE_CACHE_PATH") do
      nil -> nil
      "" -> nil
      path -> path
    end
  end

  defp optimize_jpegs(cache) do
    jpeg_files =
      Path.wildcard("#{@images_dir}/**/*.{jpg,jpeg}", match_dot: false)

    if Enum.empty?(jpeg_files) do
      {0, 0, cache}
    else
      case System.find_executable("jpegoptim") do
        nil ->
          Mix.shell().error("jpegoptim not found. Install with: sudo apt install jpegoptim")
          {0, 0, cache}

        jpegoptim ->
          jpeg_files
          |> Enum.reject(&fingerprinted?/1)
          |> Enum.reduce({0, 0, cache}, fn file, {count, savings, cache} ->
            process_file(cache, file, fn -> optimize_jpeg(jpegoptim, file) end, {count, savings})
          end)
      end
    end
  end

  defp optimize_pngs(cache) do
    png_files = Path.wildcard("#{@images_dir}/**/*.png", match_dot: false)

    if Enum.empty?(png_files) do
      {0, 0, cache}
    else
      png_tool = System.find_executable("oxipng") || System.find_executable("optipng")
      pngquant = System.find_executable("pngquant")

      case png_tool do
        nil ->
          Mix.shell().error("PNG optimizer not found. Install with: sudo apt install optipng")
          {0, 0, cache}

        tool ->
          if is_nil(pngquant) do
            Mix.shell().info(
              "  pngquant not found - skipping lossy PNG step (lossless only).\n" <>
                "       Install: brew install pngquant / sudo apt install pngquant"
            )
          end

          png_files
          |> Enum.reject(&fingerprinted?/1)
          |> Enum.reduce({0, 0, cache}, fn file, {count, savings, cache} ->
            process_file(
              cache,
              file,
              fn -> optimize_png(tool, pngquant, file) end,
              {count, savings}
            )
          end)
      end
    end
  end

  defp optimize_webps(cache) do
    webp_files = Path.wildcard("#{@images_dir}/**/*.webp", match_dot: false)

    if Enum.empty?(webp_files) do
      {0, 0, cache}
    else
      case System.find_executable("cwebp") do
        nil ->
          Mix.shell().error("cwebp not found. Install with: sudo apt install webp")
          {0, 0, cache}

        cwebp ->
          webp_files
          |> Enum.reject(&fingerprinted?/1)
          |> Enum.reduce({0, 0, cache}, fn file, {count, savings, cache} ->
            process_file(cache, file, fn -> optimize_webp(cwebp, file) end, {count, savings})
          end)
      end
    end
  end

  defp process_file(cache, file, optimize_fn, {count, savings}) do
    case optimization_status(cache, file) do
      {:already_optimized, cache} ->
        {count, savings, cache}

      {:restored_from_cache, cache} ->
        {count + 1, savings, cache}

      {{:needs_optimization, source_sha256}, cache} ->
        case optimize_fn.() do
          {:ok, saved} ->
            cache = store_in_cache(cache, file, source_sha256)
            mark_optimized(file)
            {count + 1, savings + saved, cache}

          {:error, _} ->
            {count, savings, cache}
        end
    end
  end

  defp optimization_status(cache, file) do
    source_stat = File.stat!(file)

    if already_optimized?(file, source_stat) do
      {:already_optimized, cache}
    else
      source_sha256 = sha256_hex!(file)

      if is_nil(cache.path) do
        {{:needs_optimization, source_sha256}, cache}
      else
        rel_path = Path.relative_to(file, @images_dir)

        if cache_hit?(cache.manifest, rel_path, source_sha256) do
          cached_file = Path.join(cache.path, rel_path)

          if File.exists?(cached_file) do
            File.cp!(cached_file, file)
            mark_optimized(file)
            source_size = source_stat.size
            restored_size = File.stat!(file).size
            saved = source_size - restored_size

            if saved > 0 do
              Mix.shell().info(
                "  #{Path.basename(file)}: restored from cache (saved #{format_bytes(saved)})"
              )
            end

            {:restored_from_cache, cache}
          else
            {{:needs_optimization, source_sha256}, cache}
          end
        else
          {{:needs_optimization, source_sha256}, cache}
        end
      end
    end
  end

  defp cache_hit?(manifest, rel_path, source_sha256) do
    entry = Map.get(manifest["entries"], rel_path)

    if is_nil(entry) do
      false
    else
      entry["source_sha256"] == source_sha256 && entry["cache_version"] == @cache_version
    end
  end

  defp store_in_cache(%{path: nil} = cache, _file, _source_sha256), do: cache

  defp store_in_cache(%{path: cache_path, manifest: manifest} = cache, file, source_sha256) do
    rel_path = Path.relative_to(file, @images_dir)
    dest = Path.join(cache_path, rel_path)

    File.mkdir_p!(Path.dirname(dest))
    File.cp!(file, dest)

    entries = Map.get(manifest, "entries", %{})

    new_entries =
      Map.put(entries, rel_path, %{
        "source_sha256" => source_sha256,
        "cache_version" => @cache_version
      })

    new_manifest = Map.put(manifest, "entries", new_entries)
    %{cache | manifest: new_manifest}
  end

  defp already_optimized?(file, source_stat) do
    marker_file = file <> @optimized_marker

    case File.stat(marker_file) do
      {:ok, marker_stat} ->
        marker_stat.mtime >= source_stat.mtime

      {:error, _} ->
        false
    end
  end

  defp fingerprinted?(file) do
    basename = Path.basename(file, Path.extname(file))
    String.match?(basename, ~r/-[a-f0-9]{32}$/)
  end

  defp mark_optimized(file) do
    marker_file = file <> @optimized_marker
    File.write!(marker_file, "")
  end

  defp optimize_jpeg(jpegoptim, file) do
    size_before = File.stat!(file).size

    case System.cmd(jpegoptim, ["--strip-all", "--quiet", file]) do
      {_, 0} ->
        size_after = File.stat!(file).size
        saved = size_before - size_after

        if saved > 0 do
          Mix.shell().info("  #{Path.basename(file)}: saved #{format_bytes(saved)}")
        end

        {:ok, max(saved, 0)}

      {output, _} ->
        Mix.shell().error("  Failed to optimize #{Path.basename(file)}: #{output}")
        {:error, output}
    end
  end

  defp optimize_png(png_tool, pngquant, file) do
    size_before = File.stat!(file).size

    if pngquant do
      case System.cmd(pngquant, [
             "--quality=65-85",
             "--force",
             "--ext",
             ".png",
             "--strip",
             file
           ]) do
        {_, 0} ->
          :ok

        {_, 99} ->
          :ok

        {output, code} ->
          Mix.shell().info(
            "  pngquant exited #{code} for #{Path.basename(file)}: #{String.trim(output)}"
          )
      end
    end

    args =
      cond do
        String.ends_with?(png_tool, "oxipng") ->
          ["--opt", "2", "--strip", "safe", "--quiet", file]

        String.ends_with?(png_tool, "optipng") ->
          ["-o2", "-strip", "all", "-quiet", file]

        true ->
          ["--opt", "2", "--strip", "safe", "--quiet", file]
      end

    case System.cmd(png_tool, args) do
      {_, 0} ->
        size_after = File.stat!(file).size
        saved = size_before - size_after

        if saved > 0 do
          Mix.shell().info("  #{Path.basename(file)}: saved #{format_bytes(saved)}")
        end

        {:ok, max(saved, 0)}

      {output, _} ->
        Mix.shell().error("  Failed to optimize #{Path.basename(file)}: #{output}")
        {:error, output}
    end
  end

  defp optimize_webp(cwebp, file) do
    size_before = File.stat!(file).size
    temp_file = file <> ".tmp"

    case System.cmd(cwebp, ["-lossless", "-q", "75", file, "-o", temp_file]) do
      {_, 0} ->
        size_after = File.stat!(temp_file).size
        saved = size_before - size_after

        if saved > 0 do
          File.rename!(temp_file, file)
          Mix.shell().info("  #{Path.basename(file)}: saved #{format_bytes(saved)}")
          {:ok, max(saved, 0)}
        else
          File.rm!(temp_file)
          {:ok, 0}
        end

      {output, _} ->
        if File.exists?(temp_file), do: File.rm!(temp_file)
        Mix.shell().error("  Failed to optimize #{Path.basename(file)}: #{output}")
        {:error, output}
    end
  end

  defp sha256_hex!(file) do
    :crypto.hash(:sha256, File.read!(file)) |> Base.encode16(case: :lower)
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
