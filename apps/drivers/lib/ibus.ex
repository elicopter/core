defmodule Drivers.IBus.State do
  defstruct [:bus_pid, :got_partial_frame, :channels]
end

defmodule Drivers.IBus do
  use Drivers.Common
  alias Drivers.IBus.State

  @max_channels 10
  @sync_byte 0x20

  def init([bus_pid, configuration]) do
    :ok = uart().open(bus_pid, configuration[:bus_name], speed: 115_200, active: true)
    :ok = uart().configure(bus_pid, framing: {Nerves.UART.Framing.Line, separator: " "}, rx_framing_timeout: 500)
    {:ok, %State{bus_pid: bus_pid, got_partial_frame: false}}
  end

  def start_link(bus_pid, configuration, opts \\ []) do
    Logger.debug "Starting #{__MODULE__}..."
    GenServer.start_link(__MODULE__, [bus_pid, configuration], opts)
  end

  def handle_call(:read, _from, %{got_partial_frame: false, channels: channels} = state) do
    {:reply, {:ok, channels}, state}
  end

  def handle_call(:read, _from, %{got_partial_frame: true} = state) do
    {:reply, {:ok, nil}, state}
  end

  def handle_info({:nerves_uart, _tty, {:partial, partial_frame}}, state) do
    {:noreply, %{state | got_partial_frame: true}}
  end

  def handle_info({:nerves_uart, _tty, frame}, state) do
    # TODO: Refactor, add checksum
    if byte_size(frame) == 31 do
      state = %{state | channels: parse_frame(frame)}
      {:noreply, %{state | got_partial_frame: false}}
    else
      {:noreply, %{state | got_partial_frame: false}}
    end
  end

  defp parse_frame(frame) do
    %{
      "0" => channel_value(frame, 0),
      "1" => channel_value(frame, 1),
      "2" => channel_value(frame, 2),
      "3" => channel_value(frame, 3),
      "4" => channel_value(frame, 4),
      "5" => channel_value(frame, 5),
      "6" => channel_value(frame, 6),
      "7" => channel_value(frame, 7),
      "8" => channel_value(frame, 8),
      "9" => channel_value(frame, 9)
    }
  end

  defp channel_value(frame_bytes, channel_number) do
    <<value :: little-unsigned-16>> = binary_part(frame_bytes, channel_number * 2 + 1, 2)
    value
  end
end
