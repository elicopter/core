defmodule Receiver.Ibus do
  use GenServer
  use Bitwise
  require String
  require Logger

  @uart Application.get_env(:core, :uart)

  @max_channels 10
  @sync_byte 0x20

  def init({uart_pid, device}) do
    :ok = @uart.open(uart_pid, device, speed: 115_200, active: true)
    :ok = @uart.configure(uart_pid, framing: {Nerves.UART.Framing.Line, separator: " "}, rx_framing_timeout: 500)
    {:ok,
      %{
        uart_pid: uart_pid,
        last_frame: nil,
        channels: nil,
        got_partial_frame: false
      }
    }
  end

  def start_link(uart_pid, device, name) do
    Logger.debug "Starting #{__MODULE__}..."
    GenServer.start_link(__MODULE__, {uart_pid, device}, name: name)
  end

  def handle_call(:read, _from, %{got_partial_frame: false} = state) do
    {:reply, state[:channels], state}
  end

  def handle_call(:read, _from, %{got_partial_frame: true} = state) do
    {:reply, nil, state}
  end

  def handle_info({:nerves_uart, "ttyS0", {:partial, partial_frame}}, state) do
    {:noreply, %{state | got_partial_frame: true}}
  end

  def handle_info({:nerves_uart, "ttyS0", frame}, state) do
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

  def read(pid \\ :receiver) do
    GenServer.call(pid, :read)
  end
end
