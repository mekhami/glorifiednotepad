defmodule Mix.Tasks.Videos.Optimize do
  @moduledoc """
  Optimizes videos in priv/static/videos/ using ffmpeg.

  ## Usage

      mix videos.optimize

  This task will:
  - Find all .mp4 files in priv/static/videos/
  - Generate a .webm (VP9) sibling for each — this is the primary browser format
  - Re-encode the .mp4 in place (H.264, CRF 28, no audio, faststart)
  - Report size savings
  - Skip already-optimized videos (idempotent via .optimized marker files)

  ## Required System Dependencies

  - ffmpeg (handles both WebM and MP4 encoding)

  Install on Ubuntu/Debian:

      sudo apt install ffmpeg

  Install on macOS:

      brew install ffmpeg

  """

  use Mix.Task

  @videos_dir "priv/static/videos"
  @optimized_marker ".optimized"

  @shortdoc "Optimizes videos in priv/static/videos/ using ffmpeg"

  def run(_args) do
    Mix.shell().info("Optimizing videos in #{@videos_dir}...")

    unless File.dir?(@videos_dir) do
      Mix.shell().info("No videos directory found at #{@videos_dir}, skipping optimization")
    else
      case System.find_executable("ffmpeg") do
        nil ->
          Mix.shell().error(
            "ffmpeg not found. Install with: sudo apt install ffmpeg (Linux) or brew install ffmpeg (macOS)"
          )

        ffmpeg ->
          mp4_files =
            Path.wildcard("#{@videos_dir}/**/*.mp4", match_dot: false)
            |> Enum.reject(&already_optimized?/1)

          if Enum.empty?(mp4_files) do
            Mix.shell().info("All videos already optimized")
          else
            {count, savings} =
              Enum.reduce(mp4_files, {0, 0}, fn file, {count, savings} ->
                case optimize_video(ffmpeg, file) do
                  {:ok, saved} ->
                    mark_optimized(file)
                    {count + 1, savings + saved}

                  {:error, _} ->
                    {count, savings}
                end
              end)

            Mix.shell().info("\nOptimized #{count} videos")
            Mix.shell().info("Saved #{format_bytes(savings)} total")
          end
      end
    end
  end

  defp optimize_video(ffmpeg, mp4_file) do
    webm_file = String.replace_suffix(mp4_file, ".mp4", ".webm")
    tmp_mp4 = mp4_file <> ".tmp.mp4"

    _mp4_size_before = File.stat!(mp4_file).size

    with {:ok, webm_size} <- generate_webm(ffmpeg, mp4_file, webm_file),
         {:ok, mp4_saved} <- reencode_mp4(ffmpeg, mp4_file, tmp_mp4) do
      total_saved = mp4_saved + webm_size
      {:ok, total_saved}
    else
      {:error, reason} ->
        # Clean up any partial temp file
        if File.exists?(tmp_mp4), do: File.rm!(tmp_mp4)
        {:error, reason}
    end
  end

  defp generate_webm(ffmpeg, input, output) do
    Mix.shell().info("  Generating #{Path.basename(output)}...")

    case System.cmd(
           ffmpeg,
           [
             "-i",
             input,
             "-c:v",
             "libvpx-vp9",
             "-crf",
             "33",
             "-b:v",
             "0",
             "-an",
             "-y",
             output
           ], stderr_to_stdout: true) do
      {_, 0} ->
        size = File.stat!(output).size
        Mix.shell().info("  #{Path.basename(output)}: #{format_bytes(size)}")
        {:ok, size}

      {output_log, code} ->
        Mix.shell().error("  Failed to generate WebM (exit #{code}): #{output_log}")
        {:error, output_log}
    end
  end

  defp reencode_mp4(ffmpeg, input, tmp_output) do
    size_before = File.stat!(input).size

    Mix.shell().info("  Re-encoding #{Path.basename(input)}...")

    case System.cmd(
           ffmpeg,
           [
             "-i",
             input,
             "-c:v",
             "libx264",
             "-crf",
             "28",
             "-an",
             "-movflags",
             "+faststart",
             "-y",
             tmp_output
           ], stderr_to_stdout: true) do
      {_, 0} ->
        size_after = File.stat!(tmp_output).size
        saved = max(size_before - size_after, 0)

        File.rename!(tmp_output, input)

        if saved > 0 do
          Mix.shell().info("  #{Path.basename(input)}: saved #{format_bytes(saved)}")
        end

        {:ok, saved}

      {output_log, code} ->
        if File.exists?(tmp_output), do: File.rm!(tmp_output)
        Mix.shell().error("  Failed to re-encode MP4 (exit #{code}): #{output_log}")
        {:error, output_log}
    end
  end

  defp already_optimized?(file) do
    marker_file = file <> @optimized_marker
    File.exists?(marker_file)
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
