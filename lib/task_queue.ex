defmodule TaskQueue do
  defmodule Task do
    defstruct [
      :id,
      :child_spec,
      :created_at,
      :failure_count,
      # :return_at,
      :ref
    ]
  end

  defstruct next_id: 1,
            max_parallel: 5,
            max_failures: 5,
            unstarted: [],
            in_progress: %{},
            supervisor: nil
  use Flipper, [
    :max_parallel,
    :max_failures,
  ]

  def validate_flag(:max_parallel, value, _) when is_integer(value), do: value >= 0
  def validate_flag(:max_parallel, _, _), do: false
  def validate_flag(:max_failures, value, _) when is_integer(value), do: value >= 0
  def validate_flag(:max_failures, _, _), do: false

  use GenServer
  require Logger

  def start_link(name: name) do
    Logger.info("Starting queue: #{name}")
    GenServer.start_link(__MODULE__, [], name: name)
  end

  def child_spec(args = [name: name]) do
    %{id: name, start: {__MODULE__, :start_link, [args]}}
  end

  def init(_args) do
    {:ok, supervisor} = DynamicSupervisor.start_link(strategy: :one_for_one)
    Process.send_after(self(), :update_and_reschedule, 10_000)
    {:ok, %TaskQueue{supervisor: supervisor}}
  end

  @doc """
  Get N tasks and mark them as being returned to the pool in X seconds
  """
  def get_tasks(queue, return_time, limit \\ 10) do
    GenServer.call(queue, {:get_tasks, return_time, limit})
  end

  @doc """
  Start a task in this queue via the supervisor
  """
  def start_child(queue, child_spec) do
    GenServer.call(queue, {:start_child, child_spec})
  end

  def handle_call({:start_child, child_spec}, _from, queue) do
    task = %Task{
      id: queue.next_id,
      child_spec: child_spec,
      created_at: :calendar.universal_time(),
      failure_count: 0,
      ref: nil
      # return_at: nil
    }

    Logger.info("Child added: #{inspect(child_spec)}")

    {:reply, {:ok, task},
     %{queue | next_id: queue.next_id + 1, unstarted: [task | queue.unstarted]}}
  end

  def handle_call(:update_tasks, _from, queue) do
    queue = update_tasks(queue)
    {:reply, :ok, queue}
  end

  def handle_info({:DOWN, _ref, :process, pid, :normal}, queue) do
    task = Map.get(queue.in_progress, pid)

    if task do
      IO.puts("Task successfully: #{inspect(task)}")
    end

    in_progress = Map.delete(queue.in_progress, pid)
    {:noreply, %{queue | in_progress: in_progress}}
  end

  def handle_info({:DOWN, _ref, :process, pid, reason}, queue) do
    task = Map.get(queue.in_progress, pid)

    unstarted =
      if task do
        IO.puts("Task failed: #{inspect(task)} because #{inspect(reason)}")
        task = %{task | failure_count: task.failure_count + 1, ref: nil}
        [task | queue.unstarted]
      else
        queue.unstarted
      end

    in_progress = Map.delete(queue.in_progress, pid)
    {:noreply, %{queue | in_progress: in_progress, unstarted: unstarted}}
  end

  def handle_info(:update_and_reschedule, state) do
    state = update_tasks(state)
    Process.send_after(self(), :update_and_reschedule, 10_000)
    {:noreply, state}
  end

  defp update_tasks(queue) do
    start_count = queue.max_parallel - (Map.keys(queue.in_progress) |> length)

    sorted =
      Enum.sort(queue.unstarted, fn a, b -> a.created_at < b.created_at end)
      |> Enum.filter(fn task -> task.failure_count < queue.max_failures end)

    to_start = Enum.take(sorted, start_count)
    remaining = Enum.drop(sorted, start_count)

    if to_start != [] do
      Logger.info("Starting #{start_count} tasks")
    end

    in_progress =
      to_start
      |> Stream.map(fn task ->
        Logger.info("Starting #{inspect(task.child_spec)}")

        case DynamicSupervisor.start_child(queue.supervisor, task.child_spec) do
          {:ok, pid} ->
            Logger.info("Started #{inspect(pid)}")
            ref = Process.monitor(pid)
            task = %{task | ref: ref}
            {pid, task}

          error ->
            # TODO don't fail on init failure
            exit(error)
        end
      end)
      |> Enum.into(queue.in_progress)

    %{queue | unstarted: remaining, in_progress: in_progress}
  end
end
