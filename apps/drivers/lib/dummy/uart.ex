defmodule Drivers.Dummy.UART do
  use GenServer
  require Logger

  def start_link(opts \\ []) do
    Logger.debug "Starting DUMMY #{__MODULE__}..."
    GenServer.start_link(__MODULE__, [], opts)
  end

  def open(_, _, _) do
    :ok
  end

  def configure(_, _) do
    :ok
  end
end
