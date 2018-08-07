defmodule DownloadTask do
  defstruct [
    :file,
    :path,
    :url,
    :content_length,
    :downloaded_length,
    :max_download_size
  ]

  @default_headers %{
    "User-Agent" =>
      "podsearch-scraper, @willhbr, github.com/willhbr/podsearch #{
        PodcastSearch.build_info().version
      }"
  }
  # 1 GB
  @default_max_file_size 1024 * 1024 * 1000

  def start_link(url, path) do
    GenServer.start_link(__MODULE__, {url, path})
  end

  def init({url, path}) do
    with {:ok, file} = open_file(path),
         {:ok, _} = start_download(url) do
      {:ok,
       %DownloadTask{
         file: file,
         path: path,
         url: url,
         content_length: 0,
         downloaded_length: 0,
         max_download_size: @default_max_file_size
       }}
    end
  end

  defp start_download(url) do
    HTTPoison.get(
      url,
      @default_headers,
      stream_to: self(),
      follow_redirect: true
    )
  end

  defp open_file(path), do: File.open(path, [:write, :exclusive])

  alias HTTPoison.{
    AsyncHeaders,
    AsyncStatus,
    AsyncChunk,
    AsyncRedirect,
    AsyncEnd
  }

  def handle_info(%AsyncStatus{code: 200}, state), do: {:noreply, state}

  def handle_info(%AsyncStatus{code: status_code}, state)
      when status_code < 400 and status_code >= 300,
      do: {:noreply, state}

  def handle_info(%AsyncStatus{code: status_code}, state) do
    cleanup_and_stop({:error, :unexpected_status_code, status_code}, state)
  end

  def handle_info(%AsyncHeaders{headers: headers}, state) do
    content_length_header =
      Enum.find(headers, fn {header_name, _value} ->
        header_name == "Content-Length"
      end)

    if content_length_header && content_length_header > state.max_download_size do
      cleanup_and_stop({:error, :file_too_big, content_length_header}, state)
    else
      {:noreply, %{state | content_length: content_length_header}}
    end
  end

  def handle_info(%AsyncChunk{chunk: data}, state) do
    downloaded_length = state.downloaded_length + byte_size(data)

    if downloaded_length < state.max_download_size do
      IO.binwrite(state.file, data)

      {:noreply, %{state | downloaded_length: downloaded_length}}
    else
      cleanup_and_stop({:error, :file_size_exceeded, downloaded_length}, %{
        state | downloaded_length: downloaded_length
      })
    end
  end

  def handle_info(%AsyncRedirect{to: new_url}, state) do
    # TODO Allow for max redirects
    case start_download(new_url) do
      {:ok, _} ->
        {:noreply, %{state | url: new_url}}
      error ->
        cleanup_and_stop(error, state)
    end
  end

  def handle_info(%AsyncEnd{}, state) do
    File.close(state.file)
    {:stop, :normal, state}
  end

  defp cleanup_and_stop(reason, state) do
    File.rm!(state.path)
    {:stop, reason, state}
  end
end
