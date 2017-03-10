defmodule Brain.BlackBox do
  use GenServer
  require Logger
  require Poison

  def init(_) do
    {:ok, %{events_buffer: []}}
  end

  def start_link(name) do
    Logger.debug "Starting #{__MODULE__}..."
    GenServer.start_link(__MODULE__, nil, name: name)
  end

  def handle_cast(:flush, %{channel: nil, enabled: _} = state)do
    {:noreply, %{state | events_buffer: []}}
  end

  def handle_cast(:flush, %{events_buffer: events_buffer, channel: channel, enabled: true} = state) do
    # Enum.each(events_buffer, fn({routing_key, data}) ->
    #   :ok = AMQP.Basic.publish(channel, @amqp_exchange, Atom.to_string(routing_key), Poison.encode!(data))
    # end)
    {:noreply, %{state | events_buffer: []}}
  end

  def handle_cast({:trace, routing_key, filtering_key, data}, state) do
    {:noreply, %{state | events_buffer: state[:events_buffer] ++ [{routing_key, data}]}}
  end

  def trace(module, process_name, data) do
    case {module, process_name, data} do
      {Brain.PIDController, _, data} ->
        GenServer.cast(:black_box, {:trace, :pid_controllers, data[:name], data})
      {Brain.Mixer, process_name, data} ->
        GenServer.cast(:black_box, {:trace, process_name, :mixer, Enum.into(data, %{})})
      {Brain.Interpreter, process_name, data} ->
        GenServer.cast(:black_box, {:trace, process_name, :interpreter, data})
      {Brain.Loop, process_name, data} ->
        GenServer.cast(:black_box, {:trace, process_name, :brain, data})
    end
  end

  def flush(pid \\ :black_box) do
    GenServer.cast(pid, :flush)
  end
end
