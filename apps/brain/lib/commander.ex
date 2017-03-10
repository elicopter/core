defmodule Commander do
  use GenServer
  require Logger
  require Poison

  def init(_) do
    {:ok, %{}}
  end

  def start_link(name) do
    Logger.debug "Starting #{__MODULE__}..."
    GenServer.start_link(__MODULE__, nil, name: name)
  end

  # %{"process_name" => process_name, "options" => options, "command" => command} = Poison.decode!(json_payload)
  # atomized_options = for {key, val} <- options, into: %{} do
  #   cond do
  #     is_atom(key) -> {key, val}
  #     true -> {String.to_existing_atom(key), val}
  #   end
  # end
  # atomized_command      = String.to_existing_atom(command)
  # atomized_process_name = String.to_existing_atom(process_name)
  # Logger.debug("Received #{atomized_command} command for #{atomized_process_name}.")
  # :ok = GenServer.cast(atomized_process_name, {atomized_command, atomized_options})
  # Basic.ack(channel[:channel], tag)
end
