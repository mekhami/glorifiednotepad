defmodule IndieWeb.FeedController do
  use IndieWeb, :controller

  def rss(conn, _params) do
    posts = Indie.Post.published()
    base_url = get_base_url()

    xml = build_rss(posts, base_url)

    conn
    |> put_resp_content_type("application/rss+xml")
    |> send_resp(200, xml)
  end

  defp get_base_url do
    IndieWeb.Endpoint.url()
  end

  defp build_rss(posts, base_url) do
    items =
      posts
      |> Enum.map(&build_item(&1, base_url))
      |> Enum.join("\n")

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
      <channel>
        <title>glorified notepad</title>
        <link>#{base_url}</link>
        <description>participating in the indie web, expressing myself like it's y2k</description>
        <language>en-us</language>
        <atom:link href="#{base_url}/feed.rss" rel="self" type="application/rss+xml" />
    #{items}
      </channel>
    </rss>
    """
  end

  defp build_item(post, base_url) do
    pubdate = format_rfc822_date(post.date)
    body = build_rss_body(post)

    """
        <item>
          <title>#{escape_xml(post.title)}</title>
          <link>#{base_url}/p/#{post.id}</link>
          <guid>#{base_url}/p/#{post.id}</guid>
          <pubDate>#{pubdate}</pubDate>
          <description><![CDATA[#{body}]]></description>
        </item>
    """
  end

  defp build_rss_body(%{sidenotes: []} = post), do: post.html

  defp build_rss_body(post) do
    # Replace sn-anchor spans with linked superscripts pointing to footnotes
    html_with_links =
      Regex.replace(
        ~r/<span class="sn-anchor" id="[^"]*"><sup>(\d+)<\/sup><\/span>/,
        post.html,
        fn _full, num -> ~s(<a href="#fn-#{num}"><sup>#{num}</sup></a>) end
      )

    footnotes =
      post.sidenotes
      |> Enum.map(fn %{number: n, html: h} ->
        # Strip wrapping <p> tags Earmark adds so the <li> stays clean
        inner = Regex.replace(~r/\A<p>(.*)<\/p>\z/s, h, "\\1")
        ~s(<li id="fn-#{n}">#{inner}</li>)
      end)
      |> Enum.join("\n")

    html_with_links <> "\n<hr>\n<ol>\n#{footnotes}\n</ol>"
  end

  defp format_rfc822_date(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%a, %d %b %Y %H:%M:%S %z")
  end

  defp escape_xml(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end
end
