defmodule Brain.Loop do
  use GenServer
  require Logger
  alias Brain.Sensors.{Gyroscope, Accelerometer}
  alias Brain.{Receiver, PIDController, Mixer, Interpreter, BlackBox, Commander, Neopixel}
  alias Brain.Actuators.Motors

  @filter Application.get_env(:brain, :filter)
  @loop_sleep Application.get_env(:brain, :loop)[:sleep]
  @average_looptimes_required 500

  def init(_) do
    :erlang.process_flag(:priority, :high)
    Neopixel.show_calibrate()
    {:ok, _calibration_data} = Gyroscope.calibrate
    Neopixel.show_compute_looptime()
    Process.sleep(2000)
    {:ok, %{
      complete_last_loop_duration: nil,
      last_end_timestamp: nil,
      armed: false,
      looptimes: [],
      average_looptime: -1,
      mode: :rate
    }, 0}
  end

  def start_link do
    Logger.debug "Starting #{__MODULE__}..."
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def handle_info(:timeout, state) do
    :ok = BlackBox.loop_starting()
    start_timestamp = :os.system_time(:milli_seconds)
    #
    # Reads
    #
    {:ok, gyroscope}     = Gyroscope.read()
    {:ok, accelerometer} = Accelerometer.read()
    {:ok, channels}      = Receiver.channels()

    #
    # Interpretations
    #
    {:ok, auxiliaries} = Interpreter.auxiliaries(channels)
    {:ok, complementary_axes}  = @filter.update(gyroscope, accelerometer, max(1, state[:average_looptime]))

    #
    # Computations
    #
    sample_rate = max(1, state[:average_looptime])
    setpoints   = case state[:mode] do
      :rate ->
        {:ok, rate_setpoints} = Interpreter.setpoints(:rate, channels)
        [roll_rate: rate_setpoints[:roll], pitch_rate: rate_setpoints[:pitch], yaw_rate: rate_setpoints[:yaw], throttle_rate: rate_setpoints[:throttle]]
      :angle ->
        {:ok, angle_setpoints}     = Interpreter.setpoints(:angle, channels)
        {:ok, roll_rate_setpoint}  = PIDController.compute(Brain.RollAnglePIDController, complementary_axes[:roll], angle_setpoints[:roll], sample_rate)
        {:ok, pitch_rate_setpoint} = PIDController.compute(Brain.PitchAnglePIDController, complementary_axes[:pitch], -angle_setpoints[:pitch], sample_rate)
        [roll_rate: roll_rate_setpoint, pitch_rate: pitch_rate_setpoint, yaw_rate: angle_setpoints[:yaw], throttle_rate: angle_setpoints[:throttle]]
    end

    {:ok, roll}  = PIDController.compute(Brain.RollRatePIDController, gyroscope[:y], setpoints[:roll_rate], sample_rate)
    {:ok, pitch} = PIDController.compute(Brain.PitchRatePIDController, -gyroscope[:x], setpoints[:pitch_rate], sample_rate)
    {:ok, yaw}   = PIDController.compute(Brain.YawRatePIDController, -gyroscope[:z], setpoints[:yaw_rate], sample_rate)

    {:ok, distribution} = Mixer.distribute(setpoints[:throttle_rate], roll, pitch, yaw)

    #
    # Actuations
    #
    case state[:armed] do
      true  -> Motors.throttles(distribution)
      false -> Motors.throttles(["1": 0, "2": 0, "3": 0, "4": 0])
    end

    #
    # Looptime
    #

    state = case {state[:average_looptime], length(state[:looptimes])}  do
      {-1, looptimes_length} when looptimes_length < @average_looptimes_required ->
        end_timestamp = :os.system_time(:milli_seconds)
        complete_last_loop_duration = end_timestamp - start_timestamp
        Map.merge(state, %{
          complete_last_loop_duration:  complete_last_loop_duration,
          last_end_timestamp:           end_timestamp,
          looptimes:                    [complete_last_loop_duration | state[:looptimes]]
        })
      {-1, looptimes_length} when looptimes_length == @average_looptimes_required ->
        end_timestamp = :os.system_time(:milli_seconds)
        average_looptime = Enum.reduce(state[:looptimes], 0, fn(looptime, average_looptime) -> looptime + average_looptime end) / @average_looptimes_required
        Neopixel.show_ready()
        Logger.info("#{__MODULE__} average looptime computed: #{average_looptime}.")
        Map.merge(state, %{
          complete_last_loop_duration:  end_timestamp - start_timestamp,
          last_end_timestamp:           end_timestamp,
          average_looptime:             average_looptime
        })
      _ ->
        end_timestamp = :os.system_time(:milli_seconds)
        Map.merge(state, %{
          complete_last_loop_duration:  end_timestamp - start_timestamp,
          last_end_timestamp:           end_timestamp,
          armed:                        toggle_motors(auxiliaries[:armed], state[:armed], setpoints[:throttle_rate]),
          mode:                         toggle_flight_mode(auxiliaries[:mode], state[:mode])
        })
    end

    #
    # Logging
    #
    trace(state)
    
    {:noreply, state, @loop_sleep}
  end

  def trace(state) do
    data = %{
      complete_last_loop_duration: state[:complete_last_loop_duration]
    }
    BlackBox.trace(__MODULE__, Process.info(self())[:registered_name], data)
  end

  def to_csv(data) do
    {:ok, data |> Map.values |> Enum.join(",")}
  end

  def csv_headers(data) do
    {:ok, data |> Map.keys |> Enum.join(",")}
  end

  def toggle_motors(auxiliaries_armed, state_armed, throttle) do
    case {auxiliaries_armed, state_armed, throttle < 5} do
      {true, false, true} ->
        :ok = GenServer.cast(Brain.RollAnglePIDController, :reset)
        :ok = GenServer.cast(Brain.PitchAnglePIDController, :reset)
        :ok = GenServer.cast(Brain.RollRatePIDController, :reset)
        :ok = GenServer.cast(Brain.PitchRatePIDController, :reset)
        :ok = GenServer.cast(Brain.YawRatePIDController, :reset)
        Motors.arm
        Logger.info("Motors armed.")
        Neopixel.show_armed()
        BlackBox.start_recording_loops()
        :ok = BlackBox.update_status(:armed, true)
        true
      {false, true, _} ->
        Motors.disarm
        Logger.info("Motors disarmed.")
        Neopixel.show_ready()
        BlackBox.stop_recording_loops()
        :ok = BlackBox.update_status(:armed, false)
        false
      _ ->
        state_armed
    end
  end

  def toggle_flight_mode(auxiliaries_mode, state_mode) do
    case auxiliaries_mode == state_mode do
      true ->
        state_mode
      false ->
        Logger.info("Switch to #{auxiliaries_mode} mode.")
        :ok = BlackBox.update_status(:flight_mode, auxiliaries_mode)
        auxiliaries_mode
    end
  end
end
