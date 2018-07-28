defmodule FeedParser do
  def parse(url) do
    HTTPoison.get!(url).body
    |> ElixirFeedParser.parse
    |> Feed.from_feed
  end
end
