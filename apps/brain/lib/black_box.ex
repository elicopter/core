defmodule Brain.BlackBox do
  use GenServer
  require Logger
  require Poison

  @events_buffer_limit Application.get_env(:brain, Brain.BlackBox)[:buffer_limit]
  @flush_interval Application.get_env(:brain, Brain.BlackBox)[:flush_interval]

  def init(_) do
    :timer.send_after(10, :send_last_event)
    :timer.send_interval(1000, :send_status)
    {:ok, %{events_buffer: %{}, status: %{}}}
  end

  def start_link() do
    Logger.debug "Starting #{__MODULE__}..."
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def handle_info(:send_last_event, state) do
    Enum.each(state[:events_buffer], fn({key, data}) ->
      :ok = Api.Endpoint.broadcast! "black_box:#{key}", "data", data |> List.first
    end)
    :timer.send_after(@flush_interval, :send_last_event)
    {:noreply, state}
  end

  def handle_info(:send_status, state) do
    with {:ok, status} <- status(state) do
      :ok = Api.Endpoint.broadcast!("black_box:status", "data", status)
    end
    {:noreply, state}
  end

  def handle_cast({:trace, key, data}, %{events_buffer: events_buffer} = state) do
    events = case events_buffer[key] do
      nil -> [data]
      events when length(events) < @events_buffer_limit ->
        [data | events]
      events when length(events) == @events_buffer_limit ->
        events = List.delete_at(events, @events_buffer_limit - 1)
        [data | events]
    end
    events_buffer = Map.put(events_buffer, key, events)
    {:noreply, %{state | events_buffer: events_buffer}}
  end

  def handle_call(:snapshot, _from,  %{events_buffer: events_buffer} = state) do
    last_events = Enum.map(events_buffer, fn({key, events}) ->
      {key, List.first(events)}
    end)
    {:reply, {:ok, last_events}, state}
  end

  def handle_call(:status, _from, state) do
    {:reply, status(state), state}
  end

  def handle_cast({:update_status, key, value}, %{status: status} = state) do
    {:noreply, %{state | status: Map.put(status, key, value)}}
  end

  def trace(module, process_name, data) do
    event = case {module, process_name, data} do
      {Brain.Mixer, _process_name, data} ->
        {:trace, :mixer, Enum.into(data, %{})}
      {Brain.Interpreter, _process_name, data} ->
        {:trace, :interpreter, data}
      {Brain.Filter.Complementary, _process_name, data} ->
        {:trace, :filter, data}
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

  def status do
    GenServer.call(__MODULE__, :status)
  end

  def update_status(key, value) do
    GenServer.cast(__MODULE__, {:update_status, key, value})
  end

  defp system_status do
    {uptime, _} = :erlang.statistics(:wall_clock)
    {:ok, %{
      memory: :erlang.memory() |> Enum.into(%{}),
      processes: processes(),
      uptime: uptime
    }}
  end

  defp status(%{status: status} = _state) do
    with {:ok, system_status} <- system_status() do
      {:ok, Map.merge(status, system_status)}
    end
  end

  defp processes do
    Process.list |> Enum.reduce([], fn(pid, acc) -> 
      process_info = Process.info(pid)
      process_info = %{
        name:               process_info[:registered_name],
        stack_size:         process_info[:stack_size],
        message_queue_size: process_info[:message_queue_len],
        heap_size:          process_info[:heap_size],
        memory:             process_info[:memory],
        status:             process_info[:status]
      }
      case process_info[:name] do
        name when is_atom(name) or is_binary(name) ->
          [process_info | acc]
        _ -> acc
      end
    end) |> Enum.filter(fn (process) -> process_selected?(process[:name]) end) 
  end

  defp process_selected?(process_name) do
    process_name = "#{process_name}"
    process_name |> String.contains?("Brain")
  end
end

