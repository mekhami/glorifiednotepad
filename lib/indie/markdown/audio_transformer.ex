defmodule Indie.Markdown.AudioTransformer do
  @moduledoc """
  Pre-processor that transforms [audio:/path/to/file.mp3] shorthand into
  an `<audio>` HTML element with progressive enhancement class.

  Syntax:
      [audio:/audio/my-episode.mp3]

  Output:
      <audio class="indie-audio" src="/audio/my-episode.mp3" preload="none" controls></audio>

  The `controls` attribute provides native browser playback out of the box.
  The `indie-audio` class is used by indie_audio_player.js to progressively
  enhance the element with custom-styled controls.

  Supported audio formats: any format the browser supports (mp3, ogg, wav, flac, etc.)
  """

  @audio_pattern ~r/\[audio:([^\]]+)\]/

  @spec transform(String.t()) :: String.t()
  def transform(markdown) do
    Regex.replace(@audio_pattern, markdown, fn _full, path ->
      ~s(<audio class="indie-audio" src="#{path}" preload="none" controls></audio>)
    end)
  end
end
