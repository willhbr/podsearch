defmodule Downloader do
  @download_location "/data/pods"
  def download_podcast(item) do
    id = (item.guid || item.title)
         |> String.replace(~r/[^\w]+/, "_")
    File.mkdir(@download_location)
    download_path = @download_location <> "/" <> id
    Download.from(item.episode_url, path: download_path, follow_redirect: true)
    |> case do
      {:ok, path} -> {:ok, path}
      {:error, :eexist} -> {:ok, download_path}
      error -> error
    end
  end
end
