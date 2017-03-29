defmodule Brain.BlackBox do
  use GenServer
  require Logger
  require Poison

  @loops_buffer_limit Application.get_env(:brain, Brain.BlackBox)[:loops_buffer_limit]
  @send_loop_interval Application.get_env(:brain, Brain.BlackBox)[:send_loop_interval]

  def init(_) do
    :timer.send_after(10, :send_last_loop)
    :timer.send_interval(1000, :send_status)
    :erlang.process_flag(:priority, :low)
    {:ok, %{loops_buffer: [], status: %{}}}
  end

  def start_link do
    Logger.debug "Starting #{__MODULE__}..."
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def handle_info(:send_last_loop, %{loops_buffer: []} = state) do
    :timer.send_after(@send_loop_interval, :send_last_loop)
    {:noreply, state}
  end

  def handle_info(:send_last_loop, %{loops_buffer: [_current_loop | nil]} = state) do
    :timer.send_after(@send_loop_interval, :send_last_loop)
    {:noreply, state}
  end

  def handle_info(:send_last_loop, %{loops_buffer: [_current_loop | [last_loop | _]]} = state) do
    Enum.each(last_loop, fn({key, data}) ->
      :ok = Api.Endpoint.broadcast! "black_box:#{key}", "data", data
    end)
    :timer.send_after(@send_loop_interval, :send_last_loop)
    {:noreply, state}
  end

  def handle_info(:send_status, state) do
    with {:ok, status} <- status(state) do
      :ok = Api.Endpoint.broadcast!("black_box:status", "data", status)
    end
    {:noreply, state}
  end

  def handle_cast(:start_loop, %{loops_buffer: loops_buffer} = state) do
    {:noreply, %{state | loops_buffer: [[] | loops_buffer]}}
  end

  def handle_cast(:flush_loop, state) do
    {:ok, state} = flush_loop(state)
    {:noreply, state}
  end

  def handle_cast({:trace, key, data}, %{loops_buffer: loops_buffer} = state) do
    [last_loop | previous_loops] = loops_buffer
    last_loop                    = [{key, data} | last_loop]
    if length(previous_loops) >= @loops_buffer_limit do
      previous_loops = previous_loops |> Enum.drop(-1)
    end
    {:noreply, %{state | loops_buffer: [last_loop | previous_loops]}}
  end

  def handle_call(:snapshot, _from,  %{loops_buffer: [last_loop, _]} = state) do
    {:reply, {:ok, last_loop}, state}
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

  def start_loop do
    GenServer.cast(__MODULE__, :start_loop)
  end

  def flush_loop do
    GenServer.cast(__MODULE__, :flush_loop)
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

  defp flush_loop(state) do
    file_path = build_loop_file_path()
    with {:ok, file} <- File.open(file_path, [:write, :utf8]),
      :ok            <- IO.write(file, state[:current_loop]) do
        {:ok, %{state | current_loop: []}}
    end
  end

  defp build_loop_file_path do
    {uptime, _} = :erlang.statistics(:wall_clock)
    root_path   = Application.get_env(:brain, :storage)[:root_path]
    file_path   = root_path <> "/loop_" <> uptime <> ".csv"
    {:ok, file_path}
  end
end
