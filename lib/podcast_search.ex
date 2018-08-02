defmodule PodcastSearch do
  use BuildInfo

  def download_latest(url) do
    file = Feed.parse_from_url(url).episodes
    |> hd
    |> Downloader.download_podcast
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

  use Application

  def start(_type, _args) do
    IO.puts build_info()
    children = [
      {DynamicSupervisor, strategy: :one_for_one, name: JobSupervisor}
    ]
    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
