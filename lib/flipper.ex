defmodule Flipper do
  @doc """
  Generate methods for flipping the attributes in the state variable
  """
  defmacro __using__(opts) do
    quote do
      def validate_flag(_, _, _) do
        {:error, :invalid_flag}
      end
      defoverridable validate_flag: 3

      def handle_call({:set_flag, flag, value}, _from, state) when flag in unquote(opts) do
        case validate_flag(flag, value, state) do
          :ok ->
            {:reply, :ok, %{state | flag => value}}
          true ->
            {:reply, :ok, %{state | flag => value}}
          false ->
            {:reply, {:error, :validate_failed}, state}
          error ->
            {:reply, error, state}
        end
      end

      def handle_call({:set_flag, _flag, _}, _from, state) do
        {:reply, {:error, :unknown_flag}, state}
      end

      def handle_call({:get_flag, flag}, _from, state) when flag in unquote(opts) do
        {:reply, {:ok, Map.get(state, flag)}, state}
      end

      def handle_call({:get_flag, _flag}, _from, state) do
        {:reply, {:error, :unknown_flag}, state}
      end

      def handle_call(:list_flags, _from, state) do
        {:reply, unquote(opts), state}
      end
    end
  end

  def flip(pid, flag, value) do
    GenServer.call(pid, {:set_flag, flag, value})
  end

  def get(pid, flag) do
    GenServer.call(pid, {:get_flag, flag})
  end

  def list(pid) do
    GenServer.call(pid, :list_flags)
  end
end
