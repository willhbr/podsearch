defmodule Flipper do
  @doc """
  Generate methods for flipping the attributes in the state variable
  """
  defmacro __using__(opts) do
    IO.inspect opts
    res = Enum.map(opts, fn
      attr when is_atom(attr) ->
        generate_flipper(attr)
      attr ->
        raise "Attributes should be atoms, got: #{inspect(attr)}"
    end)
    res = quote do
      unquote_splicing(res)
      def validate_flag(_, _, _) do
        {:error, :invalid_flag}
      end
      defoverridable validate_flag: 3

      def handle_call(:list_flags, _from, state) do
        {:reply, unquote(opts), state}
      end
    end
    res |> Macro.to_string |> IO.puts
    res
  end

  defp generate_flipper(attr) do
    quote do
      def handle_call({:set_flag, unquote(attr), value}, _from, state) do
        case validate_flag(unquote(attr), value, state) do
          :ok ->
            {:reply, :ok, %{state | unquote(attr) => value}}
          true ->
            {:reply, :ok, %{state | unquote(attr) => value}}
          false ->
            {:reply, {:error, :validate_failed}, state}
          error ->
            {:reply, error, state}
        end
      end

      def handle_call({:get_flag, unquote(attr)}, _from, state) do
        value = state[unquote(attr)]
        {:reply, {:ok, value}, state}
      end
      def validate_flag(unquote(attr), state) do
        :ok
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
