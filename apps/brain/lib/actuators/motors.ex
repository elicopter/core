defmodule Brain.Actuators.Motors do
  use GenServer
  require Logger

  @arm_value 1010
  @disarm_value 500
  @minimum_pwm_value 1100
  @maximum_pwm_value 4000
  @motor_count 4

  def init([driver_pid]) do
    {:ok, %{driver_pid: driver_pid}}
  end

  def start_link(driver_pid) do
    Logger.debug "Starting #{__MODULE__}..."
    GenServer.start_link(__MODULE__, [driver_pid], name: __MODULE__)
  end

  def handle_call(:arm, _from, %{driver_pid: driver_pid} = state) do
    pwm_values = [] ++ List.duplicate(@arm_value, @motor_count)
    :ok = GenServer.call(driver_pid, {:write, pwm_values})
    {:reply, :ok, state}
  end

  def handle_call(:disarm, _from, %{driver_pid: driver_pid} = state) do
    pwm_values = [] ++ List.duplicate(@disarm_value, @motor_count)
    :ok = GenServer.call(driver_pid, {:write, pwm_values})
    {:reply, :ok, state}
  end

  def handle_call({:throttles, raw_values}, _from, %{driver_pid: driver_pid} = state) do
    pwm_values = Enum.map(Keyword.values(raw_values), &filter_value/1)
    :ok = GenServer.call(driver_pid, {:write, pwm_values})
    {:reply, {:ok, pwm_values}, state}
  end

  def arm() do
    GenServer.call(__MODULE__, :arm)
  end

  def disarm() do
    GenServer.call(__MODULE__, :disarm)
  end

  def throttles(values) do
    GenServer.call(__MODULE__, {:throttles, values})
  end

  defp filter_value(value) do
    value          = max(0, min(value, 1000))
    range          = @maximum_pwm_value - @minimum_pwm_value
    relative_value = (range / 1000) * value
    round(@minimum_pwm_value + relative_value)
  end

  def minimum_pwm_value do
    @minimum_pwm_value
  end

  def maximum_pwm_value do
    @maximum_pwm_value
  end
end
