defmodule Brain.Sensors.Gyroscope do
  use GenServer
  use Sensors.Common
  require Logger

  def init([driver_pid]) do
    {:ok, %{driver_pid: driver_pid}}
  end

  def start_link(driver_pid) do
    Logger.debug "Starting #{__MODULE__}..."
    GenServer.start_link(__MODULE__, [driver_pid], name: __MODULE__)
  end
end
