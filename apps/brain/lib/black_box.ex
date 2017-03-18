defmodule Brain.BlackBox do
  use GenServer
  require Logger
  require Poison

  @buffer_limit Application.get_env(:brain, Brain.BlackBox)[:buffer_limit]
  @flush_interval Application.get_env(:brain, Brain.BlackBox)[:flush_interval]

  def init(_) do
    :timer.send_after(10, :flush)
    {:ok, %{buffer: %{}}}
  end

  def start_link() do
    Logger.debug "Starting #{__MODULE__}..."
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def handle_info(:flush, state) do
    Enum.each(state[:buffer], fn({key, data}) ->
      :ok = Api.Endpoint.broadcast! "black_box:#{key}", "data", data |> List.first
    end)
    :timer.send_after(@flush_interval, :flush)
    {:noreply, state}
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
      {Brain.Mixer, _process_name, data} ->
        {:trace, :mixer, Enum.into(data, %{})}
      {Brain.Interpreter, _process_name, data} ->
        {:trace, :interpreter, data}
      {Brain.Filter.Complementary, _process_name, data} ->
        {:trace, :filter, data}
      # {Brain.PIDController, process_name, data} ->
      #   pid_name = process_name |> Module.split |> List.last |> Macro.underscore |> String.replace("_pid_controller", "")
      #   data     = Map.merge(data, %{name: pid_name})
      #   {:trace, :pids, data}
      {Brain.Loop, _process_name, data} ->
        {:trace, :loop, data}
      {_, process_name, data} ->
        {:trace, process_name |> Module.split |> List.last |> Macro.underscore, data}
    end
    GenServer.cast(__MODULE__, event)
  end

  def snapshot do
    GenServer.call(__MODULE__, :snapshot)
  end
end
