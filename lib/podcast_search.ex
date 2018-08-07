defmodule PodcastSearch do
  use BuildInfo
  use Application

  def download_latest(url) do
    file =
      Feed.parse_from_url(url).episodes
      |> hd
      |> download_podcast()
      |> case do
        {:ok, path} -> path
      end

    Encoder.start_link(file)
    |> case do
      {:ok, pid} -> pid
    end
    |> PortTask.await(30_000)

    Transcriber.start_link(file <> ".wav")
  end

  @download_location "/data/pods"
  def download_podcast(item) do
    id =
      (item.guid || item.title)
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

  def start(_type, _args) do
    IO.puts(build_info())

    children = [
      {TaskQueue, name: EncoderQueue}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
