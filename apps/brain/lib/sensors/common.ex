defmodule Sensors.Common do
  defmacro __using__(_opts) do
    quote do
      def handle_call(:configuration, _from, %{driver_pid: driver_pid} = state) do
        {:ok, driver_configuration} = GenServer.call(driver_pid, :configuration)
        configuration = %{
          driver_configuration: driver_configuration
        }
        {:reply, configuration, state}
      end
    end
  end
end
