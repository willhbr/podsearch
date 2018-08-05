defmodule Encoder do
  use PortTask

  def start_link(path) do
    PortTask.start_link __MODULE__, [path]
  end

  def init(path) do
    output = path <> ".wav"
    unless File.exists? path do
      exit "File doesn't exist: #{path}"
    end
    File.rm(output)
    {:ok, [
      "ffmpeg",
      "-i", path,
      "-acodec", "pcm_s16le",
      "-ar", "16000",
      "-ac", "1",
      output
    ], {nil, nil}}
  end

  def handle_output(_port, contents, {total, progress}) do
    total = if total do
      total
    else
      case Regex.run(~r/TLEN\s+:\s+(\d+)/, contents) do
        [_all, length] ->
          {time, ""} = Integer.parse(length)
          time / 1000
        _ -> nil
      end
    end
    progress = case Regex.run(~r/time=(\d\d):(\d\d):(\d\d)/, contents) do
      [_all, h, m, s] ->
        [h, m, s] = Enum.map([h, m, s], fn t ->
          {t, ""} = Integer.parse(t)
          t
        end)
        (
          h * 60 * 60 +
          m * 60 +
          s
        )
      _ -> progress
    end
    {:ok, {total, progress}}
  end

  def get_progress(_port, {total, progress}) do
    if total == nil || progress == nil do
      0
    else
      progress / total
    end
  end
end
