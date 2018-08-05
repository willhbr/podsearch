defmodule Transcriber do
  use PortTask
  def start_link(path) do
    PortTask.start_link __MODULE__, [path]
  end

  def init(path) do
    {:ok, [
      "pocketsphinx_continuous",
      "-time", "1",
      "-infile", path], {"", [], nil}}
  end

  def get_transcript(pid) do
    GenServer.call(pid, :get_transcript)
  end

  def handle_call(:get_transcript, _from, state = {_, transcript, _}) do
    {:reply, transcript, state}
  end

  def handle_output(_port, contents, state) do
    {last, new_words, progress} = process_data_message(contents, state)
    {:ok, {last, new_words, progress}}
  end

  def process_data_message(contents, {prev_line, transcript, progress}) do
    lines = String.split(prev_line <> contents, "\n")
    # TODO Make this suck less
    last = List.last(lines)

    additional_words = :lists.droplast(lines)
    |> Stream.map(fn line ->
      Regex.replace(~r/\(\d+\)/, line, "")
      |> handle_line()
    end)
    |> Enum.filter(fn word -> word != :drop end)

    new_words = Enum.into(additional_words, transcript)

    progress = case List.first(additional_words) do
      {_, time} ->
        time
      _ -> progress
    end

    {last, new_words, progress}
  end

  def handle_line("INFO: " <> _log) do
    :drop
  end

  def handle_line(line) do
    contents = String.split(line, " ")
    case contents do
      [word, start, _fin, _duration] ->
        case Float.parse start do
          {start, ""} -> {word, start}
          _ -> :drop
        end
      _ -> :drop
    end
  end

  def get_progress(_port, {_, _, progress}) do
    progress
  end
end
