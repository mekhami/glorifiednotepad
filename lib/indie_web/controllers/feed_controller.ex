defmodule IndieWeb.FeedController do
  use IndieWeb, :controller

  def rss(conn, _params) do
    posts = Indie.Post.all()
    base_url = get_base_url(conn)

    xml = build_rss(posts, base_url)

    conn
    |> put_resp_content_type("application/rss+xml")
    |> send_resp(200, xml)
  end

  defp get_base_url(conn) do
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

    """
        <item>
          <title>#{escape_xml(post.title)}</title>
          <link>#{base_url}##{post.id}</link>
          <guid>#{base_url}##{post.id}</guid>
          <pubDate>#{pubdate}</pubDate>
          <description><![CDATA[#{post.html}]]></description>
        </item>
    """
  end

  defp format_rfc822_date(%Date{} = date) do
    datetime = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
    Calendar.strftime(datetime, "%a, %d %b %Y %H:%M:%S +0000")
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
