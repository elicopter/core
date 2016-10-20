defmodule Motors do
  use GenServer
  require Logger
  alias Driver.PCA9685, as: PWM

  @arm_value 1010
  @disarm_value 500
  @minimum_pwm_value 1100
  @maximum_pwm_value 4000
  @motor_count 4

  def init({pwm_pid}) do
    {:ok, %{
        pwm_pid: pwm_pid
      }
    }
  end

  def start_link(pwm_pid, name \\ :motors) do
    Logger.debug "Starting #{__MODULE__}..."
    GenServer.start_link(__MODULE__, {pwm_pid}, name: name)
  end

  def handle_call(:arm, _from, %{pwm_pid: pwm_pid} = state) do
    data = [] ++ List.duplicate(@arm_value, @motor_count)
    PWM.write(data, pwm_pid)
    {:reply, :ok, state}
  end

  def handle_call(:disarm, _from, %{pwm_pid: pwm_pid} = state) do
    data = [] ++ List.duplicate(@disarm_value, @motor_count)
    PWM.write(data, pwm_pid)
    {:reply, :ok, state}
  end

  def handle_call({:throttles, raw_values}, _from, %{pwm_pid: pwm_pid} = state) do
    values  = Enum.map(Keyword.values(raw_values), &filter_value/1)
    PWM.write(values, pwm_pid)
    {:reply, {:ok, values}, state}
  end

  def arm(pid \\ :motors) do
    GenServer.call(pid, :arm)
  end

  def disarm(pid \\ :motors) do
    GenServer.call(pid, :disarm)
  end

  def throttles(values, pid \\ :motors) do
    GenServer.call(pid, {:throttles, values})
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
