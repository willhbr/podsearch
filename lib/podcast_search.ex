defmodule PodcastSearch do
  use BuildInfo
  use Application

  def start(_type, _args) do
    IO.puts(build_info())

    children = [
      # TODO Allow for changing thresholds with args
      {TaskQueue, name: Queues.Downloader},
      {TaskQueue, name: Queues.Encoder},
      {TaskQueue, name: Queues.Transcriber},
      {Task.Supervisor, name: CrawlerSupervisor}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
