defmodule Brain.Neopixel do
  use GenServer
  require Logger

  @configuration Application.get_env(:brain, __MODULE__)
  @neopixel Application.get_env(:brain, :neopixel)

  def init([]) do
    {:ok, neopixel_pid} = @neopixel.start_link(@configuration[:channel0])
    {:ok, %{neopixel_pid: neopixel_pid, pulse_spawned_pid: nil}}
  end

  def start_link() do
    Logger.debug "Starting #{__MODULE__}..."
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def handle_cast(:calibrate, state) do
    data = List.duplicate({0, 0, 255}, 8)
    @neopixel.render(0, {50, data})
    {:noreply, state}
  end

  def handle_cast(:compute_looptime, state) do
    data = List.duplicate({255, 165, 0}, 8)
    @neopixel.render(0, {50, data})
    {:noreply, state}
  end


  def handle_cast(:ready, state) do
    # TODO: find why the pulse crash the http firmware update...
    # {:ok, pulse_spawned_pid} = pulse(0, @configuration[:channel0][:count], [color: {47, 86, 233}])
    data = List.duplicate({0, 255, 0}, 8)
    @neopixel.render(0, {50, data})
    {:noreply, state}
  end

  def handle_cast(:armed, %{pulse_spawned_pid: pulse_spawned_pid} = state) do
    data = List.duplicate({255, 0, 0}, 8)
    @neopixel.render(0, {50, data})
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
    @neopixel.render(channel, {brightness, data})
    :timer.sleep(5)
    brightness =
      if direction == :up, do: brightness + 1, else: brightness - 1
    pulse_indef(channel, data, brightness, direction)
  end

  def show_ready do
    GenServer.cast(__MODULE__, :ready)
  end

  def show_armed do
    GenServer.cast(__MODULE__, :armed)
  end

  def show_calibrate do
    GenServer.cast(__MODULE__, :calibrate)
  end

  def show_compute_looptime do
    GenServer.cast(__MODULE__, :compute_looptime)
  end
end
