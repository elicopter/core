defmodule Drivers.Dummy.I2c do
  use GenServer
  require Logger

  def init({name, address, listener}) do
    {:ok, %{
        name: name,
        address: address,
        register_address: nil,
        registers: %{},
        listener: listener
      }
    }
  end

  def start_link(name, address, opts, listener \\ nil) do
    Logger.debug "Starting DUMMY #{__MODULE__}..."
    GenServer.start_link(__MODULE__, {name, address, listener}, opts)
  end

  def write(pid, value) do
    GenServer.call(pid, {:write, value})
  end

  def read(pid, length) do
    GenServer.call(pid, {:read, length})
  end

  def write_device(pid, i2c_address, value) do
    GenServer.call(pid, {:write_device, i2c_address, value})
  end

  def read_device(pid, i2c_address, length) do
    GenServer.call(pid, {:read_device, i2c_address, length})
  end

  def handle_call({:set_listener, listener_pid}, _from, state) do
    {:reply, :ok, %{state | listener: listener_pid}}
  end

  def handle_call({:write, <<register_address>> = data}, _from, state) do
    if state[:listener], do: send(state[:listener], {:write, data})
    {:reply, :ok, %{state | register_address: register_address}}
  end

  def handle_call({:write, <<register_address, value :: binary>> = data}, _from, state) do
    if state[:listener], do: send(state[:listener], {:write, data})
    {:reply, :ok, %{state | registers: Map.put(state[:registers], register_address, value)}}
  end

  def handle_call({:write_device, _, <<register_address>> = data}, _from, state) do
    if state[:listener], do: send(state[:listener], {:write, data})
    {:reply, :ok, %{state | register_address: register_address}}
  end

  def handle_call({:write_device, _, <<register_address, value :: binary>> = data}, _from, state) do
    if state[:listener], do: send(state[:listener], {:write, data})
    {:reply, :ok, %{state | registers: Map.put(state[:registers], register_address, value)}}
  end

  def handle_call({:read, length}, _from, state) do
    if state[:listener], do: send(state[:listener], {:read, length})
    case state do
      %{name: _, address: 0x6B, register_address: 0x0F} ->
        {:reply, <<0xD7>>, state}
      %{name: _, address: 0x77, register_address: 0xD0} ->
        {:reply, <<0x55>>, state}
      %{name: _, address: 0x1E, register_address: 0x00} ->
        {:reply, <<0x10>>, state}
      %{name: _, address: 0x19, register_address: 0x20} ->
        {:reply, <<0x97>>, state}
      _ ->
       {:reply, generate_random_binary(length), state}
    end
  end

  def handle_call({:read_device, _, length}, _from, state) do
    if state[:listener], do: send(state[:listener], {:read, length})
    case state do
      %{name: _, address: _, register_address: 0x0F} ->
        {:reply, <<0xD7>>, state}
      %{name: _, address: _, register_address: 0xD0} ->
        {:reply, <<0x55>>, state}
      %{name: _, address: _, register_address: 0x00} ->
        {:reply, <<0x10>>, state}
      %{name: _, address: _, register_address: 0x20} ->
        {:reply, <<0x97>>, state}
      _ ->
       {:reply, generate_random_binary(length), state}
    end
  end

  defp generate_random_binary(length) do
    generate_random_binary(<<>>, length)
  end

  defp generate_random_binary(accumulator, 0) do
    accumulator
  end

  defp generate_random_binary(accumulator, length) do
    <<round(:rand.uniform() * 255)>> <> generate_random_binary(accumulator, length - 1)
  end

  def set_listener(listener_pid, pid) do
    GenServer.call(pid, {:set_listener, listener_pid})
  end
end
