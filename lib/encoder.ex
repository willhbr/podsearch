defmodule Encoder do
  def reencode(path, output) do
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
    # Task.start_link(__MODULE__, :poke, [self()])
    # {:ok, initial_state(port)}
  end
end
