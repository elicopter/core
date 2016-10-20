defmodule Commander do
  use GenServer
  use AMQP
  require Logger
  require Poison

  @amqp_exchange Application.get_env(:core, :commander_rabbitmq)[:exchange]
  @rabbitmq_url  Application.get_env(:core, :commander_rabbitmq)[:url]

  def init(_) do
    {:ok, %{
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
    {:noreply, %{state | channel: nil}}
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

  def handle_info({:basic_consume_ok, %{consumer_tag: _}}, channel) do
    {:noreply, channel}
  end

  def handle_info({:basic_cancel, %{consumer_tag: _}}, channel) do
    {:stop, :normal, channel}
  end

  def handle_info({:basic_cancel_ok, %{consumer_tag: _}}, channel) do
    {:noreply, channel}
  end

  def handle_info({:basic_deliver, payload, %{delivery_tag: tag, redelivered: redelivered}}, channel) do
    spawn fn ->
      consume(channel, tag, redelivered, payload)
    end
    {:noreply, channel}
  end

  defp connect do
    case Connection.open(@rabbitmq_url) do
      {:ok, connection} ->
        # Get notifications when the connection goes down
        Process.monitor(connection.pid)
        {:ok, channel} = Channel.open(connection)
        Exchange.topic(channel, "commands", durable: true)
        Queue.declare(channel, "core", durable: true)
        Queue.bind(channel, "core", "commands", routing_key: "*")
        {:ok, _consumer_tag} = Basic.consume(channel, "core")
        Logger.debug "#{__MODULE__} connected RabbitMQ."
        {:ok, channel}
      {:error, error} ->
        Logger.warn "#{__MODULE__} failed to connect RabbitMQ, wait and retry..."
        :timer.send_after(1000, :reconnect)
        {:ok, nil}
    end
  end

  defp consume(channel, tag, _, json_payload) do
    %{"process_name" => process_name, "options" => options, "command" => command} = Poison.decode!(json_payload)
    atomized_options = for {key, val} <- options, into: %{} do
      cond do
        is_atom(key) -> {key, val}
        true -> {String.to_existing_atom(key), val}
      end
    end
    atomized_command      = String.to_existing_atom(command)
    atomized_process_name = String.to_existing_atom(process_name)
    Logger.debug("Received #{atomized_command} command for #{atomized_process_name}.")
    :ok = GenServer.cast(atomized_process_name, {atomized_command, atomized_options})
    Basic.ack(channel[:channel], tag)
  end
end
