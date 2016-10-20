defmodule Filter.Complementary do
  require Logger

  @pi          3.14159265359
  @sample_rate Application.get_env(:core, :sample_rate)

  def init(_) do
    {:ok,
      %{
        sample_rate: @sample_rate,
        roll: 0,
        pitch: 0,
        yaw: 0,
        alpha: 0.995
      }
    }
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

  def start_link(name \\ :complementary_ilter) do
    Logger.debug "Starting #{__MODULE__}..."
    GenServer.start_link(__MODULE__, nil, name: name)
  end

  def update(gyroscope, accelerometer, pid \\ :filter) do
    GenServer.call(pid, {:update, gyroscope, accelerometer})
  end
end
