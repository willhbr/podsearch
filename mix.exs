defmodule PodcastSearch.MixProject do
  use Mix.Project

  def project do
    [
      app: :podcast_search,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :elixir_feed_parser],
      mod: {PodcastSearch, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      elixir_feed_parser: "~> 0.0.1",
      httpoison: "~> 1.0"
      # download: "~> 0.0.4",
    ] ++
      [
        {:download, git: "https://github.com/willhbr/download"}
      ]
  end
end
