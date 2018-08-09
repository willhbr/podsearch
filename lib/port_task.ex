defmodule PortTask do
  defmacro __using__(_opts) do
    quote do
      import PortTask

      def child_spec(args) do
        %{
          id: __MODULE__,
          start: {PortTask, :start_link, [__MODULE__, args]},
          type: :worker,
          restart: :temporary
        }
      end

      def handle_finish(_port, _reason, _state), do: nil
      defoverridable handle_finish: 3

      @callback get_command(term()) :: [String.t()]
      @callback handle_output(Port.t(), String.t(), term()) ::
                  {:ok, term()} | {:stop, term()}
      @callback get_progress(Port.t(), term()) :: Integer.t()
    end
  end

  use GenServer
  require Logger

  def start_link(module, args) do
    GenServer.start_link(PortTask, {module, args})
  end

  def init({module, args}) do
    {binary, args, state} =
      :erlang.apply(module, :init, [args])
      |> case do
        {:ok, [binary | args], state} -> {binary, args, state}
        error -> raise error
      end

    exec = System.find_executable(binary)

    port =
      Port.open(
        {:spawn_executable, exec},
        [:binary, :stderr_to_stdout, args: args]
      )

    Port.connect(port, self())
    Port.monitor(port)
    {:ok, {port, module, state}}
  end

  def handle_info({port, {:data, contents}}, {port, module, state}) do
    :erlang.apply(module, :handle_output, [port, contents, state])
    |> case do
      {:ok, new_state} ->
        {:noreply, {port, module, new_state}}

      {:stop, reason, new_state} ->
        {:stop, reason, {port, module, new_state}}
    end
  end

  def handle_info({:DOWN, _ref, :port, port, reason}, s = {port, module, state}) do
    Logger.info("#{module} finished")
    :erlang.apply(module, :handle_finish, [port, reason, state])
    {:stop, reason, s}
  end

  def handle_call(:get_progress, _from, s = {port, module, state}) do
    progress = :erlang.apply(module, :get_progress, [port, state])
    {:reply, progress, s}
  end

  def handle_call(:stop, _from, state = {port, _, _}) do
    Port.close(port)
    {:stop, :normal, :ok, state}
  end

  def get_progress(pid) do
    GenServer.call(pid, :get_progress)
  end

  def stop(pid) do
    GenServer.call(pid, :stop)
  end

  def await(pid, timeout \\ 5000) do
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^pid, _, _, reason} -> reason
    after
      timeout ->
        Process.demonitor(ref)
        :timeout
    end
  end
end
