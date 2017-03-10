defmodule Brain.Loop do
  use GenServer
  require Logger
  alias Brain.Sensors.{Gyroscope, Accelerometer}
  alias Brain.{Receiver, PIDController, Mixer, Interpreter, BlackBox, Commander}
  alias Brain.Actuators.Motors

  @filter        Application.get_env(:brain, :filter)
  @sample_rate   Application.get_env(:brain, :sample_rate)

  def init(_) do
    # TODO implement reverse on pids
    :ok = PIDController.configure(Brain.RollRatePIDController, {0.7, 0, 0, -500, 500})
    :ok = PIDController.configure(Brain.PitchRatePIDController, {0.7, 0, 0, -500, 500})
    :ok = PIDController.configure(Brain.YawRatePIDController, {3.5, 0, 0, -500, 500})

    :ok = PIDController.configure(Brain.RollAnglePIDController, {1.9, 0, 0, -400, 400})
    :ok = PIDController.configure(Brain.PitchAnglePIDController, {-1.9, 0, 0, -400, 400})

    {:ok, _calibration_data} = Gyroscope.calibrate

    :timer.send_interval(@sample_rate, :loop)
    {:ok, %{
      complete_last_loop_duration: nil,
      last_end_timestamp: nil,
      armed: false,
      mode: :angle
    }}
  end

  def start_link do
    Logger.debug "Starting #{__MODULE__}..."
    GenServer.start_link(__MODULE__, nil, name: :brain)
  end

  def handle_info(:loop, state) do
    start_timestamp = :os.system_time(:milli_seconds)
    {:ok, gyroscope}       = Gyroscope.read()
    {:ok, accelerometer}   = Accelerometer.read()
    {:ok, channels}        = Receiver.channels()

    delta_with_last_loop = case state[:last_end_timestamp] do
      nil -> 0
      _ -> start_timestamp - state[:last_end_timestamp]
    end

    {:ok, rate_setpoints} = Interpreter.setpoints(:rate, channels)
    {:ok, auxiliaries}    = Interpreter.auxiliaries(channels)

    {:ok, complementary_axes}  = @filter.update(gyroscope, accelerometer)

    if state[:mode] == :rate do
      roll_rate_setpoint    = rate_setpoints[:roll]
      pitch_rate_setpoint   = rate_setpoints[:pitch]
      angle_setpoints       = nil
    else
      {:ok, angle_setpoints}     = Interpreter.setpoints(:angle, channels)
      :ok                        = PIDController.update_setpoint(Brain.RollAnglePIDController, angle_setpoints[:roll])
      {:ok, roll_rate_setpoint}  = PIDController.compute(Brain.RollAnglePIDController, complementary_axes[:roll])
      :ok                        = PIDController.update_setpoint(Brain.PitchAnglePIDController, -angle_setpoints[:pitch])
      {:ok, pitch_rate_setpoint} = PIDController.compute(Brain.PitchAnglePIDController, complementary_axes[:pitch])
    end

    yaw_rate_setpoint = rate_setpoints[:yaw]

    :ok          = PIDController.update_setpoint(Brain.RollRatePIDController, roll_rate_setpoint)
    {:ok, roll}  = PIDController.compute(Brain.RollRatePIDController, gyroscope[:y])

    :ok          = PIDController.update_setpoint(Brain.PitchRatePIDController, pitch_rate_setpoint)
    {:ok, pitch} = PIDController.compute(Brain.PitchRatePIDController, -gyroscope[:x])

    :ok          = PIDController.update_setpoint(Brain.YawRatePIDController, yaw_rate_setpoint)
    {:ok, yaw}   = PIDController.compute(Brain.YawRatePIDController, -gyroscope[:z])

    throttle     = rate_setpoints[:throttle]

    {:ok, distribution} = Mixer.distribute(throttle, roll, pitch, yaw)

    if state[:armed] == true, do: Motors.throttles(distribution)

    state = %{state | armed: toggle_motors(auxiliaries[:armed], state[:armed], rate_setpoints[:throttle])}
    state = %{state | mode: toggle_flight_mode(auxiliaries[:mode], state[:mode])}

    end_timestamp = :os.system_time(:milli_seconds)
    new_state     = Map.merge(state, %{
      complete_last_loop_duration: end_timestamp - start_timestamp,
      last_end_timestamp: end_timestamp
    })
    trace(new_state, %{gyroscope: gyroscope, accelerometer: accelerometer}, complementary_axes, delta_with_last_loop)
    {:noreply, new_state}
  end


  def trace(state, sensors, complementary_axes, delta_with_last_loop) do
    data = %{
      complete_last_loop_duration: state[:complete_last_loop_duration],
      delta_with_last_loop: delta_with_last_loop,
      sensors: %{
        gyroscope: sensors[:gyroscope],
        accelerometer: sensors[:accelerometer]
      },
      complementary_axes: complementary_axes
    }
    BlackBox.trace(__MODULE__, Process.info(self())[:registered_name], data)
  end

  def toggle_motors(auxiliaries_armed, state_armed, throttle) do
    case {auxiliaries_armed, state_armed, throttle < 5} do
      {true, false, true} ->
        Motors.arm
        Logger.debug("Motors armed.")
        true
      {false, true, _} ->
        Motors.disarm
        Logger.debug("Motors disarmed.")
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
        Logger.debug("Switch to #{auxiliaries_mode} mode.")
        auxiliaries_mode
    end
  end
end
