defmodule Brain do
  use GenServer
  require Logger

  @accelerometer Application.get_env(:core, :accelerometer)
  @magnetometer  Application.get_env(:core, :magnetometer)
  @gyroscope     Application.get_env(:core, :gyroscope)
  @barometer     Application.get_env(:core, :barometer)
  @receiver      Application.get_env(:core, :receiver)
  @filter        Application.get_env(:core, :filter)

  @sample_rate   Application.get_env(:core, :sample_rate)

  def init(_) do
    # TODO implement reverse on pids
    :ok = PIDController.configure({0.7, 0, 0, -500, 500}, :roll_rate_pid_controller)
    :ok = PIDController.configure({0.7, 0, 0, -500, 500}, :pitch_rate_pid_controller)
    :ok = PIDController.configure({3.5, 0, 0, -500, 500}, :yaw_rate_pid_controller)

    :ok = PIDController.configure({1.9, 0, 0, -400, 400}, :roll_angle_pid_controller)
    :ok = PIDController.configure({-1.9, 0, 0, -400, 400}, :pitch_angle_pid_controller)

    :timer.send_interval(@sample_rate, :loop)
    {:ok, %{
      complete_last_loop_duration: nil,
      last_end_timestamp: nil,
      armed: false,
      mode: :angle,
      wifi_enabled: false
    }}
  end

  def start_link do
    Logger.debug "Starting #{__MODULE__}..."
    GenServer.start_link(__MODULE__, nil, name: :brain)
  end

  def handle_info(:loop, state) do
    start_timestamp      = :os.system_time(:milli_seconds)
    gyroscope            = @gyroscope.read
    accelerometer        = @accelerometer.read
    channels             = @receiver.read

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
      :ok                        = PIDController.update_setpoint(angle_setpoints[:roll], :roll_angle_pid_controller)
      {:ok, roll_rate_setpoint}  = PIDController.compute(complementary_axes[:roll], :roll_angle_pid_controller)
      :ok                        = PIDController.update_setpoint(-angle_setpoints[:pitch], :pitch_angle_pid_controller)
      {:ok, pitch_rate_setpoint} = PIDController.compute(complementary_axes[:pitch], :pitch_angle_pid_controller)
    end

    yaw_rate_setpoint = rate_setpoints[:yaw]

    :ok          = PIDController.update_setpoint(roll_rate_setpoint,:roll_rate_pid_controller)
    {:ok, roll}  = PIDController.compute(gyroscope[:y], :roll_rate_pid_controller)

    :ok          = PIDController.update_setpoint(pitch_rate_setpoint, :pitch_rate_pid_controller)
    {:ok, pitch} = PIDController.compute(- gyroscope[:x], :pitch_rate_pid_controller)

    :ok          = PIDController.update_setpoint(yaw_rate_setpoint, :yaw_rate_pid_controller)
    {:ok, yaw}   = PIDController.compute(- gyroscope[:z], :yaw_rate_pid_controller)

    throttle     = rate_setpoints[:throttle]

    {:ok, distribution} = Mixer.distribute(throttle, roll, pitch, yaw)

    if state[:armed] == true, do: Motors.throttles(distribution)

    state = %{state | armed: toggle_motors(auxiliaries[:armed], state[:armed], rate_setpoints[:throttle])}
    state = %{state | wifi_enabled: toggle_wifi(auxiliaries[:wifi_enabled], state[:wifi_enabled])}
    state = %{state | mode: toggle_flight_mode(auxiliaries[:mode], state[:mode])}

    end_timestamp = :os.system_time(:milli_seconds)
    new_state     = Map.merge(state, %{
      complete_last_loop_duration: end_timestamp - start_timestamp,
      last_end_timestamp: end_timestamp
    })
    trace(new_state, %{gyroscope: gyroscope, accelerometer: accelerometer}, complementary_axes, delta_with_last_loop)
    BlackBox.flush
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

  def toggle_wifi(auxiliaries_wifi_enabled, state_wifi_enabled) do
    case {auxiliaries_wifi_enabled, state_wifi_enabled} do
      {true, false} ->
        enable_wifi
        true
      {false, true} ->
        disable_wifi
        false
      _ ->
        state_wifi_enabled
    end
  end

  def enable_wifi do
    wifi          = Application.get_env(:core, :wifi)
    configuration = Application.get_env(:core, :wifi_configuration)
    wifi.setup(configuration[:interface],
      ssid: configuration[:ssid],
      key_mgmt: configuration[:key_mgmt],
      psk: configuration[:psk])
    :ok = GenServer.cast(:black_box, :connect)
    :ok = GenServer.cast(:commander, :connect)
    Logger.debug("Wifi enabled.")
  end

  def disable_wifi do
    :ok = GenServer.cast(:black_box, :disconnect)
    :ok = GenServer.cast(:commander, :disconnect)
    Nerves.InterimWiFi.teardown("wlan0")
    Logger.debug("Wifi disabled.")
  end
end
