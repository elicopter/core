defmodule Brain.Mixer do
  use GenServer
  require Logger
  alias Brain.BlackBox

  def init(_) do
    {:ok, %{}}
  end

  def start_link() do
    Logger.debug "Starting #{__MODULE__}..."
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def handle_call({:distribute, throttle, roll, pitch, yaw}, _from, state) do
    distribution = [
      "1": max(0, throttle + pitch - roll - yaw),
      "2": max(0, throttle - pitch - roll + yaw),
      "3": max(0, throttle + pitch + roll + yaw),
      "4": max(0, throttle - pitch + roll - yaw)
    ]
    trace(state, distribution)
    {:reply, {:ok, distribution}, state}
  end

  defp trace(state, distribution) do
    BlackBox.trace(__MODULE__, Process.info(self())[:registered_name], distribution)
  end

  def distribute(throttle, roll, pitch, yaw) do
    GenServer.call(__MODULE__, {:distribute, throttle, roll, pitch, yaw})
  end
end
