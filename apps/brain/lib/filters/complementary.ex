defmodule Brain.Filter.Complementary do
  require Logger
  alias Brain.BlackBox

  @pi          3.14159265359
  @sample_rate Application.get_env(:brain, :sample_rate)

  def init(_) do
    {:ok,
      %{
        sample_rate: @sample_rate,
        roll: 0,
        pitch: 0,
        yaw: 0,
        alpha: 0.99
      }
    }
  end

  def start_link() do
    Logger.debug "Starting #{__MODULE__}..."
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def handle_call({:update, gyroscope_data, accelerometer_data}, _from, state) do
    pitch_accelerometer = :math.atan2(accelerometer_data[:y], accelerometer_data[:z]) * 180 / @pi
    roll_accelerometer  = :math.atan2(-accelerometer_data[:x], accelerometer_data[:z]) * 180 / @pi
    pitch_gyroscope     = state[:pitch] + (gyroscope_data[:x] * (state[:sample_rate] / 1000))
    roll_gyroscope      = state[:roll] + (gyroscope_data[:y] * (state[:sample_rate] / 1000))
    yaw_gyroscope       = state[:yaw] + (gyroscope_data[:z] * (state[:sample_rate] / 1000))
    new_state           = %{
      roll: (roll_gyroscope * state[:alpha] + roll_accelerometer * (1- state[:alpha])),
      pitch: (pitch_gyroscope * state[:alpha] + pitch_accelerometer * (1- state[:alpha])),
      yaw: yaw_gyroscope
    }
    trace(state, new_state)
    {:reply,
      {
        :ok, %{
          roll: new_state[:roll],
          pitch: new_state[:pitch],
          yaw: new_state[:yaw]
        }
      }, Map.merge(state, new_state)
    }
  end

  def handle_cast({:offset, :roll, value}, state) do
    {:noreply, %{state | roll_offset: value}}
  end

  def update(gyroscope, accelerometer, elapsed_time) do
    GenServer.call(__MODULE__, {:update, gyroscope, accelerometer})
  end

  def offset(axis, value) do
    GenServer.cast(__MODULE__, {:offset, axis, value})
  end

  defp trace(_state, data) do
    BlackBox.trace(__MODULE__, Process.info(self())[:registered_name], data)
  end

end
