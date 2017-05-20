defmodule Brain.Dummy.Neopixel do
  use GenServer
  require Logger

  def start_link(channel1, channel2 \\ [pin: 0, count: 0]) do
    GenServer.start_link(__MODULE__, [channel1, channel2], [name: __MODULE__])
  end

  def stop() do
    GenServer.stop(__MODULE__)
  end

  def render({_, _} = data) do
    render(0, data)
  end

  def render(channel, {_, _} = data) do
    GenServer.call(__MODULE__, {:render, channel, data})
  end

  def init([_ch1, _ch2]) do
    {:ok, %{}}
  end

  def handle_call({:render, _channel, {_brightness, _data}}, _from, state) do
    {:reply, :ok, state}
  end
end
