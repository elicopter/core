defmodule Interpreter do
  use GenServer
  require Logger

  @receiver_min 1000
  @receiver_max 2000
  @receiver_mid @receiver_min + (@receiver_max - @receiver_min) / 2
  @receiver_mid_interval 20

  # TO IMPROVE: need to set m/s
  @throttle_min 0
  @throttle_max 1000

  @yaw_min_rate -200
  @yaw_max_rate 200

  @pitch_min_rate -200
  @pitch_max_rate 200
  @pitch_min_angle -45
  @pitch_max_angle 45

  @roll_min_rate -200
  @roll_max_rate 200
  @roll_min_angle -45
  @roll_max_angle 45

  @roll_channel 0
  @pitch_channel 1
  @throttle_channel 2
  @yaw_channel 3

  @armed_auxiliary_channel 4
  @wifi_enabled_auxiliary_channel 9
  @mode_auxiliary_channel 8

  def init(_) do
    {:ok, %{trace: true}}
  end

  def start_link(name \\ :interpreter) do
    Logger.debug "Starting #{__MODULE__}..."
    GenServer.start_link(__MODULE__, nil, name: name)
  end

  def handle_call({:setpoints, mode, nil}, _from, state) do
    setpoints = %{throttle: 0, roll: 0, pitch: 0, yaw: 0}
    trace(state, setpoints, nil, mode)
    {:reply, {:ok, setpoints}, state}
  end

  def handle_call({:setpoints, mode, channels}, _from, state) do
    setpoints = %{
      throttle: compute_throttle_setpoint(channels["#{@throttle_channel}"], mode),
      roll: compute_roll_setpoint(channels["#{@roll_channel}"], mode),
      pitch: compute_pitch_setpoint(channels["#{@pitch_channel}"], mode),
      yaw: compute_yaw_setpoint(channels["#{@yaw_channel}"], mode)
    }
    trace(state, setpoints, channels, mode)
    {:reply, {:ok, setpoints}, state}
  end

  def handle_call({:auxiliaries, nil}, _from, state) do
    auxiliaries = %{armed: false, mode: :angle, wifi_enabled: true}
    {:reply, {:ok, auxiliaries}, state}
  end

  def handle_call({:auxiliaries, channels}, _from, state) do
    auxiliaries = %{
      armed: (if channels[Integer.to_string(@armed_auxiliary_channel)] > 1100, do: true, else: false),
      mode: (if channels[Integer.to_string(@mode_auxiliary_channel)] > 1100, do: :rate, else: :angle),
      wifi_enabled: (if channels[Integer.to_string(@wifi_enabled_auxiliary_channel)] > 1100, do: true, else: false)
    }
    {:reply, {:ok, auxiliaries}, state}
  end

  defp compute_throttle_setpoint(input, _) do
    #TODO: Need to add a PID for throttle
    map(input, @receiver_min, @receiver_max, @throttle_min, @throttle_max)
  end

  defp compute_roll_setpoint(input, mode) do
    case {input, mode, is_neutral_point(input)} do
      {_, _, true}           -> 0
      {input, :rate, false}  -> map(input, @receiver_min, @receiver_max, @roll_min_rate, @roll_max_rate)
      {input, :angle, false} -> map(input, @receiver_min, @receiver_max, @roll_min_angle, @roll_max_angle)
    end
  end

  defp compute_pitch_setpoint(input, mode) do
    case {input, mode, is_neutral_point(input)} do
      {_, _, true}           -> 0
      {input, :rate, false}  -> map(input, @receiver_min, @receiver_max, @pitch_min_rate, @pitch_max_rate)
      {input, :angle, false} -> map(input, @receiver_min, @receiver_max, @pitch_min_angle, @pitch_max_angle)
    end
  end

  defp compute_yaw_setpoint(input, mode) do
    case {input, mode, is_neutral_point(input)} do
      {_, _, true}       -> 0
      # TO IMPROVE: Only rate for yaw
      {input, _, false}  -> map(input, @receiver_min, @receiver_max, @yaw_min_rate, @yaw_max_rate)
    end
  end

  defp map(input, input_min, input_max, output_min, output_max) do
    (input - input_min) * (output_max - output_min) / (input_max - input_min) + output_min;
  end

  defp is_neutral_point(input) do
    input > @receiver_mid - @receiver_mid_interval && input < @receiver_mid + @receiver_mid_interval
  end

  defp trace(state, setpoints, channels, mode) do
    if state[:trace] do
      data = %{
        setpoints: setpoints,
        channels: channels,
        mode: mode
      }
      BlackBox.trace(__MODULE__, Process.info(self())[:registered_name], data)
    end
  end

  def setpoints(mode, channels, pid \\ :interpreter) do
    GenServer.call(pid, {:setpoints, mode, channels})
  end

  def auxiliaries(channels, pid \\ :interpreter) do
    GenServer.call(pid, {:auxiliaries, channels})
  end
end
