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

  use GenServer

  def start_link(name: name) do
    GenServer.start_link(__MODULE__, [], name: name)
  end

  def init(_args) do
    {:ok, supervisor} = DynamicSupervisor.start_link(strategy: :one_for_one)
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

    {:reply, {:ok, task},
     %{queue | next_id: queue.next_id + 1, unstarted: [task | queue.unstarted]}}
  end

  def handle_call(:update_tasks, _from, queue) do
    start_count = queue.max_parallel - (Map.keys(queue.in_progress) |> length)

    sorted =
      Enum.sort(queue.unstarted, fn a, b -> a.created_at < b.created_at end)
      |> Enum.filter(fn task -> task.failure_count < queue.max_failures end)

    to_start = Enum.take(sorted, start_count)
    remaining = Enum.drop(sorted, start_count)

    in_progress =
      to_start
      |> Stream.map(fn task ->
        case DynamicSupervisor.start_child(queue.supervisor, task.child_spec) do
          {:ok, pid} ->
            ref = Process.monitor(pid)
            task = %{task | ref: ref}
            {pid, task}

          error ->
            # TODO don't fail on init failure
            exit(error)
        end
      end)
      |> Enum.into(queue.in_progress)

    {:reply, :ok, %{queue | unstarted: remaining, in_progress: in_progress}}
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
end
