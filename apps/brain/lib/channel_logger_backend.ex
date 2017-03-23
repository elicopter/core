
defmodule Brain.ChannelLoggerBackend do
  use GenEvent
  use Timex

  def handle_event(:flush, state) do
    {:ok, state}
  end

  def handle_event({level, _group_leader, {Logger, message, timestamp, _metadata}}, state) do
    payload = %{
      timestamp: Timex.now, #TODO: parse log timestamp
      message: message |> IO.iodata_to_binary
    }
    with :ok <- Api.Endpoint.broadcast("logger:#{level |> Atom.to_string}", "data", payload) do
    else {:error, error} ->
        IO.puts "#{__MODULE__} Can't log to channel"
        IO.inspect error
        IO.inspect message
    end
    {:ok, state}
  end
end
