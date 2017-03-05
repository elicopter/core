defmodule Drivers.Dummy.Ibus do
  use GenServer
  use Bitwise
  require String
  require Logger

  def init(_) do
    {:ok, %{}}
  end

  def start_link(uart_pid, device, name) do
    Logger.debug "Starting DUMMY #{__MODULE__}..."
    GenServer.start_link(__MODULE__, {uart_pid, device}, name: name)
  end

  def handle_call(:read, _from, state) do
    channels = %{
      "0" => round(:rand.uniform() * 1000),
      "1" => round(:rand.uniform() * 1000),
      "2" => round(:rand.uniform() * 1000),
      "3" => round(:rand.uniform() * 1000),
      "4" => round(:rand.uniform() * 1000),
      "5" => round(:rand.uniform() * 1000),
      "6" => round(:rand.uniform() * 1000),
      "7" => round(:rand.uniform() * 1000),
      "8" => round(:rand.uniform() * 1000),
      "9" => round(4000)
    }
    {:reply, channels, state}
  end

  def read(pid \\ :receiver) do
    GenServer.call(pid, :read)
  end
end
