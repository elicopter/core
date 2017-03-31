defmodule Brain.Filter.Complementary do
  require Logger
  alias Brain.BlackBox

  @pi 3.14159265359
  @degrees_to_radians @pi/180

  def init(_) do
    {:ok,
      %{
        roll: 0,
        pitch: 0,
        roll_offset: 1.79,
        pitch_offset: -0.5,
        yaw: 0,
        alpha: 0.985,
        first_loop: true
      }
    }
  end

  def start_link() do
    Logger.debug "Starting #{__MODULE__}..."
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def handle_call({:update, gyroscope_data, accelerometer_data, sample_rate}, _from, %{first_loop: first_loop} = state) do
    sample_rate_in_seconds     = sample_rate / 1000
    yawed_transfer             = :math.sin(gyroscope_data[:z] * @degrees_to_radians * sample_rate_in_seconds)
    accelerometer_total_vector = :math.sqrt(:math.pow(accelerometer_data[:x], 2) + :math.pow(accelerometer_data[:y], 2) + :math.pow(accelerometer_data[:z], 2))

    pitch_accelerometer = :math.asin(accelerometer_data[:y] / accelerometer_total_vector) * (1 / @degrees_to_radians) - state[:pitch_offset]
    roll_accelerometer  = :math.asin(accelerometer_data[:x] / accelerometer_total_vector) * -(1 / @degrees_to_radians) - state[:roll_offset]

    pitch_gyroscope = state[:pitch] + (gyroscope_data[:x] * sample_rate_in_seconds)
    pitch_gyroscope = pitch_gyroscope + (pitch_gyroscope * yawed_transfer)

    roll_gyroscope = state[:roll] + (gyroscope_data[:y] * sample_rate_in_seconds)
    roll_gyroscope = roll_gyroscope + (roll_gyroscope * yawed_transfer)

    new_state = case first_loop do
      true ->
        Logger.debug("#{__MODULE__} starts with roll: #{roll_accelerometer} and pitch #{pitch_accelerometer}.")
        %{
          roll: roll_accelerometer,
          pitch: pitch_accelerometer,
          yaw: 0,
          first_loop: false
        }
      false ->
        %{
          roll: (roll_gyroscope * state[:alpha] + roll_accelerometer * (1- state[:alpha])),
          pitch: (pitch_gyroscope * state[:alpha] + pitch_accelerometer * (1- state[:alpha])),
          yaw: 0,
        }
    end
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

  def update(gyroscope, accelerometer, sample_rate) do
    GenServer.call(__MODULE__, {:update, gyroscope, accelerometer, sample_rate})
  end

  defp trace(_state, data) do
    BlackBox.trace(__MODULE__, Process.info(self())[:registered_name], data)
  end

  def to_csv(data) do
    {:ok, data |> Map.values |> Enum.join(",")}
  end

  def csv_headers(data) do
    {:ok, data |> Map.keys |> Enum.join(",")}
  end
end
