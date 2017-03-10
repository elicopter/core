defmodule Brain.BlackBox do
  use GenServer
  require Logger
  require Poison

  @buffer_limit Application.get_env(:brain, Brain.BlackBox)[:buffer_limit]

  def init(_) do
    {:ok, %{buffer: %{}}}
  end

  def start_link() do
    Logger.debug "Starting #{__MODULE__}..."
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def handle_cast({:trace, key, data}, %{buffer: buffer} = state) do
    events = case buffer[key] do
      nil -> [data]
      events when length(events) < @buffer_limit ->
        [data | events]
      events when length(events) == @buffer_limit ->
        events = List.delete_at(events, @buffer_limit - 1)
        [data | events]
    end
    buffer = Map.put(buffer, key, events)
    {:noreply, %{state | buffer: buffer}}
  end

  def handle_call(:snapshot, _from,  %{buffer: buffer} = state) do
    last_events = Enum.map(buffer, fn({key, events}) ->
      {key, List.first(events)}
    end)
    {:reply, {:ok, last_events}, state}
  end

  def trace(module, process_name, data) do
    event = case {module, process_name, data} do
      {Brain.PIDController, Brain.RollRatePIDController, data} ->
        {:trace, :roll_rate_pid_controller, data}
      {Brain.PIDController, Brain.PitchRatePIDController, data} ->
        {:trace, :pitch_rate_pid_controller, data}
      {Brain.PIDController, Brain.YawRatePIDController, data} ->
        {:trace, :yaw_rate_pid_controller, data}
      {Brain.PIDController, Brain.PitchAnglePIDController, data} ->
        {:trace, :pitch_angle_pid_controller, data}
      {Brain.PIDController, Brain.RollAnglePIDController, data} ->
        {:trace, :roll_angle_pid_controller, data}
      {Brain.Mixer, _process_name, data} ->
        {:trace, :mixer, Enum.into(data, %{})}
      {Brain.Interpreter, _process_name, data} ->
        {:trace, :interpreter, data}
      {Brain.Loop, _process_name, data} ->
        {:trace, :loop, data}
    end
    GenServer.cast(__MODULE__, event)
  end

  def snapshot do
    GenServer.call(__MODULE__, :snapshot)
  end
end
