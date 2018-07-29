defmodule Encoder do
  def reencode(path) do
    output = path <> ".wav"
    File.rm(output)
    exec = System.find_executable("ffmpeg")
    port = Port.open(
      {:spawn_executable, exec},
      [:binary,
       :stderr_to_stdout,
       args: [
         "-i", path,
         "-acodec", "pcm_s16le",
         "-ar", "16000",
         "-ac", "1",
         output]
      ]
    )
    Port.connect(port, self())
    loop(port)
    path <> ".wav"
  end

  defp loop(port) do
    receive do
      _message ->
        loop(port)
    after
      30_000 ->
        if Port.info(port) do
          loop(port)
        end
    end
  end
end
