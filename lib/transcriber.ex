defmodule Transcriber do
  use GenServer
  def start_link(path) do
    GenServer.start_link __MODULE__, path
  end

  def init(path) do
    exec = System.find_executable("pocketsphinx_continuous")
    port = Port.open(
      {:spawn_executable, exec},
      [:binary, :stderr_to_stdout, args: ["-time", "1", "-infile", path]]
    )
    Port.connect(port, self())
    Task.start_link(__MODULE__, :poke, [self()])
    {:ok, initial_state(port)}
  end

  def initial_state(port) do
    {port, "", []}
  end

  def alive?(pid) do
    GenServer.call(pid, :alive?)
  end

  def get_transcript(pid) do
    GenServer.call(pid, :get_transcript)
  end

  def handle_call(:alive?, _from, state = {port, _, _}) do
    info = Port.info(port)
    {:reply, info, state}
  end

  def handle_call(:poke, _from, state = {port, _, _}) do
    info = Port.info(port)
    if info != nil do
      {:reply, true, state}
    else
      {"", transcript} = process_data_message("", state)
      {:reply, false, {port, "", transcript}}
    end
  end

  def handle_call(:get_transcript, _from, state = {_, _, transcript}) do
    {:reply, transcript, state}
  end

  def handle_info({_port, {:data, contents}}, state = {port, _, _}) do
    {last, new_words} = process_data_message(contents, state)
    {:noreply, {port, last, new_words}}
  end

  def handle_info(info, state) do
    IO.warn(inspect(info))
    {:noreply, state}
  end

  def process_data_message(contents, {_, prev_line, transcript}) do
    lines = String.split(prev_line <> contents, "\n")
    # TODO Make this be better
    last = List.last(lines)

    new_words = :lists.droplast(lines)
    |> Stream.map(fn line ->
      Regex.replace(~r/\(\d+\)/, line, "")
      |> handle_line()
    end)
    |> Stream.filter(fn word -> word != :drop end)
    |> Enum.into(transcript)

    {last, new_words}
  end

  def handle_line("INFO: " <> log) do
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

  def poke(pid) do
    if GenServer.call(pid, :poke) do
      Process.sleep 10000
      poke(pid)
    else
      IO.puts "Server finished"
    end
  end
end
