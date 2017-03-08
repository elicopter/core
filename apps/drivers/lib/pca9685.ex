defmodule Drivers.PCA9685 do
  use Drivers.Common

  @frequency 400
  @mode_1_register 0x00
  @mode_2_register 0x01
  @prescale_register 0xFE
  @led0_on_l_register 0x06

  def init([bus_pid, configuration]) do
    set_prescale(bus_pid)
    {:ok, %State{bus_pid: bus_pid, configuration: configuration}}
  end

  def start_link(bus_pid, configuration, opts \\ []) do
    GenServer.start_link(__MODULE__, [bus_pid, configuration], opts)
  end

  def handle_call({:write, values}, _from, %State{bus_pid: bus_pid} = state) do
    zero = << 0::size(16) >>
    reducer = fn(value, acc) ->
      acc <> zero <> << value::little-16 >>
    end
    data = Enum.reduce(values, << @led0_on_l_register >>, reducer)
    i2c().write(bus_pid, data)
    {:reply, :ok, state}
  end

  def handle_call({:write, number, start_value, end_value}, _from, %State{bus_pid: bus_pid} = state) do
    register_address = << @led0_on_l_register + 4 * number >>
    data = register_address <> << start_value::little-16 >> <> << end_value::little-16 >>
    i2c().write(bus_pid, data)
    {:reply, :ok, state}
  end

  defp set_prescale(bus_pid) do
    # Reset
    i2c().write(bus_pid, <<@mode_1_register, 0x00>>)
    Process.sleep(5)
    # Read mode
    <<mode :: unsigned-8>> = i2c().read_device(bus_pid, 1)
    # Set sleep mode
    sleep_mode = (mode &&& 0x7F) ||| 0x10
    i2c().write(bus_pid, <<@mode_1_register, sleep_mode>>)
    # Write prescale
    prescale = round((25 * 1000 * 1000) / (4096 * @frequency)) - 1
    i2c().write(bus_pid, <<@prescale_register, prescale>>)
    # Reset mode
    i2c().write(bus_pid, <<@mode_1_register, mode>>)
    Process.sleep(5)
    # Set auto increment
    new_mode = mode |||  0xa1
    i2c().write(bus_pid, <<@mode_1_register, new_mode>>)
  end
end
