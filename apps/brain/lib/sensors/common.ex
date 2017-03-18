defmodule Sensors.Common do
  defmacro __using__(_opts) do
    alias Brain.BlackBox

    quote do
      def handle_call(:configuration, _from, %{driver_pid: driver_pid} = state) do
        {:ok, driver_configuration} = GenServer.call(driver_pid, :configuration)
        configuration = %{
          driver_configuration: driver_configuration
        }
        {:reply, configuration, state}
      end

      def handle_call(:read, _from, %{driver_pid: driver_pid} = state) do
        {:ok, data} = GenServer.call(driver_pid, :read)
        trace(state, data)
        {:reply, {:ok, data}, state}
      end

      def read() do
        GenServer.call(__MODULE__, :read)
      end

      defp trace(_state, data) do
        BlackBox.trace(__MODULE__, Process.info(self())[:registered_name], data)
      end
    end
  end
end
