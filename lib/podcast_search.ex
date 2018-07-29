defmodule PodcastSearch do
  def download_latest(url) do
    Feed.parse_from_url(url).episodes
    |> hd
    |> Downloader.download_podcast
    |> case do
      {:ok, path} -> path
    end
    |> Encoder.reencode
    |> Transcriber.start_link
  end
end
