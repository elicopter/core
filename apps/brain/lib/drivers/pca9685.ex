defmodule Driver.PCA9685 do
  use GenServer
  use Bitwise
  require Logger

  @i2c Application.get_env(:brain, :i2c)

  @i2c_address 0x40
  @frequency 400
  @mode_1_register 0x00
  @mode_2_register 0x01
  @prescale_register 0xFE
  @led0_on_l_register 0x06

  def init({i2c_pid}) do
    set_prescale(i2c_pid)
    {:ok, %{
        i2c_pid: i2c_pid
      }
    }
  end

  def start_link(i2c_pid, name \\ :pca9685) do
    Logger.debug "Starting #{__MODULE__}..."
    GenServer.start_link(__MODULE__, {i2c_pid}, name: name)
  end

  def handle_call({:write, values}, _from, %{i2c_pid: i2c_pid} = state) do
    zero = << 0::size(16) >>
    reducer = fn(value, acc) ->
      acc <> zero <> << value::little-16 >>
    end
    data = Enum.reduce(values, << @led0_on_l_register >>, reducer)
    @i2c.write_device(i2c_pid, @i2c_address, data)
    {:reply, :ok, state}
  end

  def handle_call({:write, number, start_value, end_value}, _from, %{i2c_pid: i2c_pid} = state) do
    register_address = << @led0_on_l_register + 4 * number >>
    data = register_address <> << start_value::little-16 >> <> << end_value::little-16 >>
    @i2c.write_device(i2c_pid, @i2c_address, data)
    {:reply, :ok, state}
  end

  defp set_prescale(i2c_pid) do
    # Reset
    @i2c.write_device(i2c_pid, @i2c_address, <<@mode_1_register, 0x00>>)
    Process.sleep(5)
    # Read mode
    <<mode :: unsigned-8>> = @i2c.read_device(i2c_pid, @i2c_address, 1)
    # Set sleep mode
    sleep_mode = (mode &&& 0x7F) ||| 0x10
    @i2c.write_device(i2c_pid, @i2c_address, <<@mode_1_register, sleep_mode>>)
    # Write prescale
    prescale = round((25 * 1000 * 1000) / (4096 * @frequency)) - 1
    @i2c.write_device(i2c_pid, @i2c_address, <<@prescale_register, prescale>>)
    # Reset mode
    @i2c.write_device(i2c_pid, @i2c_address, <<@mode_1_register, mode>>)
    Process.sleep(5)
    # Set auto increment
    new_mode = mode |||  0xa1
    @i2c.write_device(i2c_pid, @i2c_address, <<@mode_1_register, new_mode>>)
  end

  def write(number, start_value, end_value, pid \\ :pca9685) do
    GenServer.call(pid, {:write, number, start_value, end_value})
  end

  def write(values, pid \\ :pca9685) do
    GenServer.call(pid, {:write, values})
  end
end
