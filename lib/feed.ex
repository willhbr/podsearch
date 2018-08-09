defmodule Feed do
  defstruct [
    :url,
    :title,
    episodes: []
  ]

  def parse_from_url(url) do
    with {:ok, resp} <- HTTPoison.get(url, DownloadTask.default_headers()),
         body <- resp.body do
      body
      |> ElixirFeedParser.parse()
      |> from_feed
    end
  end

  def from_feed(%{url: url, title: title, entries: entries}) do
    episodes = Enum.map(entries, &Feed.Episode.from_feed_entry/1)
    %Feed{url: url, title: title, episodes: episodes}
  end

  defmodule Episode do
    defstruct [
      :episode_url,
      :type,
      :length,
      :description,
      :title,
      :guid,
      :updated,
      :url
    ]

    def from_feed_entry(entry) do
      %{
        title: title,
        description: description,
        "rss2:guid": guid,
        updated: updated,
        url: url,
        enclosure: %{
          length: leng,
          type: type,
          url: episode_url
        }
      } = entry

      %Episode{
        title: title,
        episode_url: episode_url,
        type: type,
        length: leng,
        description: description,
        guid: guid,
        updated: updated,
        url: url
      }
    end
  end
end
