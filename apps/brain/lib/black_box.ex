defmodule Brain.BlackBox do
  use GenServer
  require Logger
  require Poison
  use Brain.BlackBox.Status

  @loops_buffer_limit 100
  @send_loop_interval Application.get_env(:brain, Brain.BlackBox)[:send_loop_interval]

  def init(_) do
    {:ok, store_pid} = Brain.BlackBox.Store.start_link()
    :timer.send_after(10, :send_last_loop)
    :timer.send_interval(2000, :flush_recorded_loops)
    :timer.send_interval(1000, :send_status)
    {:ok, %{loops_buffer: [], status: %{}, loops_recording: false, store_pid: store_pid}}
  end

  def start_link do
    Logger.debug "Starting #{__MODULE__}..."
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def handle_info(:send_last_loop, %{loops_buffer: []} = state) do
    :timer.send_after(@send_loop_interval, :send_last_loop)
    {:noreply, state}
  end

  def handle_info(:send_last_loop, %{loops_buffer: [_current_loop]} = state) do
    :timer.send_after(@send_loop_interval, :send_last_loop)
    {:noreply, state}
  end

  def handle_info(:send_last_loop, %{loops_buffer: [_current_loop | [last_loop | _]]} = state) do
    Enum.each(last_loop, fn({key, {data, module}}) ->
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

  def handle_cast(:loop_starting, %{loops_buffer: loops_buffer} = state) do
    {:noreply, %{state | loops_buffer: ([[] | loops_buffer])}}
  end

  def handle_info(:flush_recorded_loops, %{loops_recording: false, loops_buffer: loops_buffer} = state)
  when length(loops_buffer) > @loops_buffer_limit do
    [current_loop | previous_loops] = loops_buffer
    loops_to_drop = length(loops_buffer) - @loops_buffer_limit
    {:noreply, %{state | loops_buffer: [current_loop | previous_loops |> Enum.drop(-loops_to_drop)]}}
  end

  def handle_info(:flush_recorded_loops, %{loops_recording: true, store_pid: store_pid, loops_buffer: [current_loop | last_loops]} = state)
  when length(last_loops) > @loops_buffer_limit do
    :ok = GenServer.cast(store_pid, {:store_recorded_loops_in_csv, last_loops})
    {:noreply, %{state | loops_buffer: [current_loop]}}
  end
  def handle_info(:flush_recorded_loops, state) do
    {:noreply, state}
  end

  def handle_cast(:stop_recording_loops, %{loops_recording: false} = state), do: {:noreply, state}
  def handle_cast(:stop_recording_loops, %{loops_recording: true, store_pid: store_pid, loops_buffer: [current_loop | last_loops]} = state) do
    Logger.info "#{__MODULE__} stopped recording loops..."
    :ok = GenServer.cast(store_pid, {:store_recorded_loops_in_csv, last_loops})
    :ok = GenServer.cast(store_pid, :stop_recording_loops)
    {:noreply, %{%{state | loops_buffer: [current_loop]} | loops_recording: false}}
  end

  def handle_cast(:start_recording_loops, %{loops_recording: false, loops_buffer: loops_buffer, store_pid: store_pid} = state = state) do
    Logger.info "#{__MODULE__} started recording loops..."
    [current_loop | [last_loop | previous_loops]] = loops_buffer
    :ok = GenServer.cast(store_pid, {:start_recording_loops, last_loop})
    {:noreply, %{state | loops_recording: true}}
  end
  def handle_cast(:start_recording_loops, state), do: {:noreply, state}

  def handle_cast({:trace, key, data, module}, %{loops_buffer: loops_buffer} = state) do
    [last_loop | previous_loops] = loops_buffer
    last_loop                    = [{key, {data, module}} | last_loop]
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
        {:trace, :mixer, Enum.into(data, %{}), module}
      {Brain.Interpreter, _process_name, data} ->
        {:trace, :interpreter, data, module}
      {Brain.Filter.Complementary, _process_name, data} ->
        {:trace, :filter, data, module}
      {Brain.Loop, _process_name, data} ->
        {:trace, :loop, data, module}
      {_, process_name, data} ->
        {:trace, process_name |> Module.split |> List.last |> Macro.underscore, data, module}
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

  def loop_starting do
    GenServer.cast(__MODULE__, :loop_starting)
  end

  def stop_recording_loops do
    GenServer.cast(__MODULE__, :stop_recording_loops)
  end

  def start_recording_loops do
    GenServer.cast(__MODULE__, :start_recording_loops)
  end
end
