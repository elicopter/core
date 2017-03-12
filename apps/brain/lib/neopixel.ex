defmodule Brain.Neopixel do
  use GenServer
  require Logger

  @configuration Application.get_env(:brain, __MODULE__)

  def init([]) do
    {:ok, neopixel_pid} = Nerves.Neopixel.start_link(@configuration[:channel0])
    {:ok, %{neopixel_pid: neopixel_pid, pulse_spawned_pid: nil}}
  end

  def start_link() do
    Logger.debug "Starting #{__MODULE__}..."
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def handle_cast(:waiting, state) do
    {:ok, pulse_spawned_pid} = pulse(0, @configuration[:channel0][:count], [color: {47, 86, 233}])
    {:noreply, %{state | pulse_spawned_pid: pulse_spawned_pid}}
  end

  def handle_cast(:armed, %{pulse_spawned_pid: pulse_spawned_pid} = state) do
    data = List.duplicate({205, 30, 16}, 8)
    Nerves.Neopixel.render(0, {100, data})
    state = case pulse_spawned_pid do
      nil -> state
      pid ->
        Process.exit(pid, :kill)
        %{state | pulse_spawned_pid: nil}
    end
    {:noreply, state}
  end

  defp pulse(channel, pixels, opts \\ []) do
    color = opts[:color] || {212, 175, 55}
    delay = opts[:delay] || 100

    data = List.duplicate(color, pixels)
    spawned_pid = spawn(fn () -> pulse_indef(channel, data, 0, :up) end)
    {:ok, spawned_pid}
  end

  defp pulse_indef(channel, data, 0, :down) do
    pulse_indef(channel, data, 1, :up)
  end

  defp pulse_indef(channel, data, 125, :up) do
    pulse_indef(channel, data, 124, :down)
  end

  defp pulse_indef(channel, data, brightness, direction) do
    Nerves.Neopixel.render(channel, {brightness, data})
    :timer.sleep(5)
    brightness =
      if direction == :up, do: brightness + 1, else: brightness - 1
    pulse_indef(channel, data, brightness, direction)
  end

  def show_waiting do
    GenServer.cast(__MODULE__, :waiting)
  end

  def show_armed do
    GenServer.cast(__MODULE__, :armed)
  end
end
