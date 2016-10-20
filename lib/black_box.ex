defmodule BlackBox do
  use GenServer
  use AMQP
  require Logger
  require Poison

  @amqp_exchange Application.get_env(:core, :black_box_rabbitmq)[:exchange]
  @rabbitmq_url  Application.get_env(:core, :black_box_rabbitmq)[:url]

  def init(_) do
    {:ok, %{
        events_buffer: [],
        counters: %{},
        take_one_every: 2,
        channel: nil,
        enabled: false
      }
    }
  end

  def start_link(name) do
    Logger.debug "Starting #{__MODULE__}..."
    GenServer.start_link(__MODULE__, nil, name: name)
  end

  def handle_cast(:connect, state) do
    {:ok, channel} = connect()
    state = %{state | enabled: true}
    {:noreply, %{state | channel: channel}}
  end

  def handle_cast(:disconnect, %{channel: channel} = state) do
    if channel, do: Channel.close(channel)
    state = %{state | enabled: false}
    {:noreply, %{state | channel: channel}}
  end

  def handle_cast(:flush, %{channel: nil, enabled: _} = state)do
    {:noreply, %{state | events_buffer: []}}
  end

  def handle_cast(:flush, %{events_buffer: events_buffer, channel: channel, enabled: true} = state) do
    Enum.each(events_buffer, fn({routing_key, data}) ->
      :ok = AMQP.Basic.publish(channel, @amqp_exchange, Atom.to_string(routing_key), Poison.encode!(data))
    end)
    {:noreply, %{state | events_buffer: []}}
  end

  def handle_cast({:trace, routing_key, filtering_key, data}, state) do
    counter  = (state[:counters][filtering_key] || 0) + 1
    counters = Map.put(state[:counters], filtering_key, counter)
    state    = %{state | counters: counters}
    need_to_push = rem(counter, state[:take_one_every]) == 0
    events_buffer = state[:events_buffer]
    if need_to_push do
      events_buffer = state[:events_buffer] ++ [{routing_key, data}]
      {:noreply, %{state | events_buffer: events_buffer}}
    else
      {:noreply, state}
    end
  end

  def handle_info(:reconnect, %{enabled: true} = state) do
    {:ok, channel} = connect()
    {:noreply, %{state | channel: channel}}
  end

  def handle_info(:reconnect, %{enabled: false} = state) do
    {:noreply, state}
  end

  def handle_info({:DOWN, _, :process, _pid, _reason}, state) do
    {:ok, channel} = connect()
    {:noreply, %{state | channel: channel}}
  end

  def trace(module, process_name, data) do
    case {module, process_name, data} do
      {PIDController, _, data} ->
        GenServer.cast(:black_box, {:trace, :pid_controllers, data[:name], data})
      {Mixer, process_name, data} ->
        GenServer.cast(:black_box, {:trace, process_name, :mixer, Enum.into(data, %{})})
      {Interpreter, process_name, data} ->
        GenServer.cast(:black_box, {:trace, process_name, :interpreter, data})
      {Brain, process_name, data} ->
        GenServer.cast(:black_box, {:trace, process_name, :brain, data})
    end
  end

  def flush(pid \\ :black_box) do
    GenServer.cast(pid, :flush)
  end

  defp connect do
    case Connection.open(@rabbitmq_url) do
      {:ok, connection} ->
        # Get notifications when the connection goes down
        Process.monitor(connection.pid)
        {:ok, channel} = Channel.open(connection)
        :ok            = AMQP.Exchange.declare(channel, @amqp_exchange, :topic, durable: true)
        Logger.debug "#{__MODULE__} connected RabbitMQ."
        {:ok, channel}
      {:error, error} ->
        Logger.warn "#{__MODULE__} failed to connect RabbitMQ, wait and retry..."
        :timer.send_after(1000, :reconnect)
        {:ok, nil}
    end
  end
end
