defmodule IndieWeb.StonetopSessionsLive do
  use IndieWeb, :live_view

  import IndieWeb.MarkdownHelpers

  alias Indie.Stonetop

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Session Notes")
     |> assign(:sessions, Stonetop.list_sessions())
     |> assign(:characters, Stonetop.list_characters())
     |> assign(:current, nil)}
  end

  @description_limit 220

  @doc """
  Renders session notes as HTML, wrapping mentions of known characters in a
  span carrying their description so it can be shown on hover.
  """
  def render_notes(notes, characters) do
    notes
    |> render_comment_markdown()
    |> link_characters(characters)
  end

  def link_characters(html, characters) do
    characters =
      characters
      |> Enum.reject(&(&1.name in [nil, ""]))
      |> Enum.sort_by(&String.length(&1.name), :desc)

    case characters do
      [] ->
        html

      _ ->
        by_name = Map.new(characters, &{escape(&1.name), &1})

        pattern =
          by_name
          |> Map.keys()
          |> Enum.sort_by(&String.length/1, :desc)
          |> Enum.map_join("|", &Regex.escape/1)
          |> then(&Regex.compile!("(?<![\\w&#])(?:#{&1})(?!\\w)", "u"))

        ~r/(<[^>]*>)/
        |> Regex.split(html, include_captures: true)
        |> Enum.map_reduce(0, fn
          "<" <> _ = tag, depth -> {tag, depth + skip_depth(tag)}
          text, 0 -> {Regex.replace(pattern, text, &mention(by_name[&1], &1)), 0}
          text, depth -> {text, depth}
        end)
        |> elem(0)
        |> IO.iodata_to_binary()
    end
  end

  # Don't decorate names inside links or code.
  defp skip_depth(tag) do
    cond do
      Regex.match?(~r/^<(a|code|pre)[\s>]/i, tag) -> 1
      Regex.match?(~r/^<\/(a|code|pre)>/i, tag) -> -1
      true -> 0
    end
  end

  defp mention(character, text) do
    ~s(<span class="character-mention" tabindex="0" data-name="#{escape(character.name)}") <>
      ~s( data-kind="#{kind(character)}") <>
      ~s( data-description="#{escape(brief(character.description))}">#{text}</span>)
  end

  defp kind(%{tags: tags}) do
    tags = Enum.map(tags || [], &String.downcase/1)

    cond do
      "pc" in tags -> "pc"
      "npc" in tags -> "npc"
      true -> ""
    end
  end

  defp brief(nil), do: ""

  defp brief(description) do
    description = description |> String.replace(~r/\s+/, " ") |> String.trim()

    if String.length(description) > @description_limit do
      String.slice(description, 0, @description_limit) |> String.trim_trailing() |> Kernel.<>("…")
    else
      description
    end
  end

  defp escape(text), do: text |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    case Stonetop.get_session_by_slug(id) do
      nil ->
        {:noreply, assign(socket, :current, nil)}

      session ->
        {:noreply,
         socket
         |> assign(:current, session)
         |> assign(:page_title, session_label(session))}
    end
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, :current, List.first(socket.assigns.sessions))}
  end

  def session_label(%{title: title, number: n}) when title in [nil, ""], do: "Session #{n}"
  def session_label(%{title: title, number: n}), do: "Session #{n}: #{title}"

  def format_date(nil), do: nil
  def format_date(date), do: Calendar.strftime(date, "%-d %B %Y")

  # Sessions are listed newest first, so the "earlier" session is the next one.
  defp neighbours(sessions, current) do
    idx = Enum.find_index(sessions, &(&1.id == current.id))
    later = if idx > 0, do: Enum.at(sessions, idx - 1)
    {Enum.at(sessions, idx + 1), later}
  end
end
