defmodule Mixer do
  use GenServer
  require Logger
  require BlackBox

  def init(_) do
    {:ok, %{trace: true}}
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
    if state[:trace] do
      BlackBox.trace(__MODULE__, Process.info(self())[:registered_name], distribution)
    end
  end

  def start_link(name \\ :mixer) do
    Logger.debug "Starting #{__MODULE__}..."
    GenServer.start_link(__MODULE__, nil, name: name)
  end

  def distribute(throttle, roll, pitch, yaw, pid \\ :mixer) do
    GenServer.call(pid, {:distribute, throttle, roll, pitch, yaw})
  end
end
