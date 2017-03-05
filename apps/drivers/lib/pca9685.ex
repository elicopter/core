defmodule Drivers.PCA9685 do
  use Drivers.Common

  @frequency 400
  @mode_1_register 0x00
  @mode_2_register 0x01
  @prescale_register 0xFE
  @led0_on_l_register 0x06

  def init([bus_pid]) do
    set_prescale(bus_pid)
    {:ok, %State{bus_pid: bus_pid}}
  end

  def start_link(bus_pid, opts \\ []) do
    GenServer.start_link(__MODULE__, [bus_pid], opts)
  end

  def handle_call({:write, values}, _from, %{bus_pid: bus_pid} = state) do
    zero = << 0::size(16) >>
    reducer = fn(value, acc) ->
      acc <> zero <> << value::little-16 >>
    end
    data = Enum.reduce(values, << @led0_on_l_register >>, reducer)
    I2c.write_device(bus_pid, @i2c_address, data)
    {:reply, :ok, state}
  end

  def handle_call({:write, number, start_value, end_value}, _from, %{bus_pid: bus_pid} = state) do
    register_address = << @led0_on_l_register + 4 * number >>
    data = register_address <> << start_value::little-16 >> <> << end_value::little-16 >>
    I2c.write_device(bus_pid, @i2c_address, data)
    {:reply, :ok, state}
  end

  defp set_prescale(bus_pid) do
    # Reset
    I2c.write_device(bus_pid, @i2c_address, <<@mode_1_register, 0x00>>)
    Process.sleep(5)
    # Read mode
    <<mode :: unsigned-8>> = I2c.read_device(bus_pid, @i2c_address, 1)
    # Set sleep mode
    sleep_mode = (mode &&& 0x7F) ||| 0x10
    I2c.write_device(bus_pid, @i2c_address, <<@mode_1_register, sleep_mode>>)
    # Write prescale
    prescale = round((25 * 1000 * 1000) / (4096 * @frequency)) - 1
    I2c.write_device(bus_pid, @i2c_address, <<@prescale_register, prescale>>)
    # Reset mode
    I2c.write_device(bus_pid, @i2c_address, <<@mode_1_register, mode>>)
    Process.sleep(5)
    # Set auto increment
    new_mode = mode |||  0xa1
    I2c.write_device(bus_pid, @i2c_address, <<@mode_1_register, new_mode>>)
  end
end
