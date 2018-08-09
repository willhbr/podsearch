defmodule FeedDownloader do
  require Logger

  def start_link(url, downloader_supervisor) do
    Task.start_link(__MODULE__, :download, [url, downloader_supervisor])
  end

  def download(url, supervisor) do
    Feed.parse_from_url(url).episodes
    |> Enum.take(12)
    |> Enum.each(fn item ->
      url = item.episode_url
      path = url_to_path(url)
      Logger.info("Adding #{url} -> #{path}")
      TaskQueue.start_child(supervisor, {DownloadTask, {url, path}})
    end)
  end

  @download_path "/data/pods/"
  def url_to_path(url) do
    filename = Regex.replace(~r/[^\w]+/, url, "_")
    @download_path <> filename
  end
end
