defmodule Drivers.PCA9685.State do
  defstruct [:bus_pid, :frequency, :computed_frequency]
end

defmodule Drivers.PCA9685 do
  use Drivers.Common
  alias Drivers.PCA9685.State

  @default_frequency 400
  @mode_1_register 0x00
  @mode_2_register 0x01
  @prescale_register 0xFE
  @led0_on_l_register 0x06

  def init([bus_pid, configuration]) do
    frequency          = configuration[:frequency] || @default_frequency
    {:ok, prescale}    = set_prescale(bus_pid, frequency)
    computed_frequency = 25_000_000 / (prescale * 4096)
    {:ok, %State{
        bus_pid: bus_pid,
        computed_frequency: computed_frequency,
        frequency: frequency
      }
    }
  end

  def start_link(bus_pid, configuration, opts \\ []) do
    GenServer.start_link(__MODULE__, [bus_pid, configuration], opts)
  end

  def handle_call({:write, values}, _from, state) do
    {:reply, write(state, values), state}
  end

  def handle_call({:write_us, values}, _from, state) do
    {:reply, write_us(state, values), state}
  end

  def handle_call({:write_ms, values}, _from, state) do
    {:reply, write_ms(state, values), state}
  end

  defp set_prescale(bus_pid, frequency) do
    # Reset
    i2c().write(bus_pid, <<@mode_1_register, 0x00>>)
    Process.sleep(5)
    # Read mode
    <<mode :: unsigned-8>> = i2c().read(bus_pid, 1)
    # Set sleep mode
    sleep_mode = (mode &&& 0x7F) ||| 0x10
    i2c().write(bus_pid, <<@mode_1_register, sleep_mode>>)
    # Write prescale
    prescale = (25 * 1000 * 1000) / (4096 * frequency)
    prescale = round(Float.floor(prescale + 0.5, 0))
    i2c().write(bus_pid, <<@prescale_register, prescale>>)
    # Reset mode
    i2c().write(bus_pid, <<@mode_1_register, mode>>)
    Process.sleep(5)
    # Set auto increment
    new_mode = mode |||  0xa1
    i2c().write(bus_pid, <<@mode_1_register, new_mode>>)
    {:ok, prescale}
  end

  defp write_ms(%State{computed_frequency: computed_frequency} = state, values) do
    values = Enum.map(values, fn value ->
      (value / ((1 / computed_frequency) * 1000)) * 4096
    end)
    write(state, values)
  end

  defp write_us(%State{computed_frequency: computed_frequency} = state, values) do
    values = Enum.map(values, fn value ->
      (value / ((1 / computed_frequency) * 1_000_000)) * 4096
    end)
    write(state, values)
  end

  defp write(%State{bus_pid: bus_pid} = state, values) do
    zero = << 0::size(16) >>
    reducer = fn(value, acc) ->
      bounded_value = round(min(max(0, value), 4095))
      acc <> zero <> << bounded_value::little-16 >>
    end
    data = Enum.reduce(values, << @led0_on_l_register >>, reducer)
    i2c().write(bus_pid, data)
    :ok
  end
end
