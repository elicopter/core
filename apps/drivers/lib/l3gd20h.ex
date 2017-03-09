defmodule Drivers.L3GD20H do
  use Drivers.Common

  @i2c_identifier 0xD7
  @whoami_register 0x0F
  @ctrl_reg1_register 0x20
  @ctrl_reg4_register 0x23
  @out_x_l_register 0x28
  @sensitivity 0.0175

  def init([bus_pid, configuration]) do
    validate_i2c_device!(bus_pid)
    i2c().write(bus_pid, <<@ctrl_reg1_register, 0xFF>>) # 800 hz
    i2c().write(bus_pid, <<@ctrl_reg4_register, 0x10>>) # 500 dps
    {:ok, %State{bus_pid: bus_pid, configuration: configuration}}
  end

  def start_link(bus_pid, configuration, opts \\ []) do
    Logger.debug "Starting #{__MODULE__}..."
    GenServer.start_link(__MODULE__, [bus_pid, configuration], opts)
  end

  def handle_call(:read, _from, %State{bus_pid: bus_pid} = state) do
    i2c().write(bus_pid, <<@out_x_l_register ||| 0x80>>)
    raw_data = i2c().read(bus_pid, 6)
    <<x :: signed-16>> = binary_part(raw_data, 1, 1) <> binary_part(raw_data, 0, 1)
    <<y :: signed-16>> = binary_part(raw_data, 3, 1) <> binary_part(raw_data, 2, 1)
    <<z :: signed-16>> = binary_part(raw_data, 5, 1) <> binary_part(raw_data, 4, 1)
    # unit: "degrees per second"
    data = %{
      x: x * @sensitivity,
      y: y * @sensitivity,
      z: z * @sensitivity
    }
    {:reply, {:ok, data}, state}
  end

  defp validate_i2c_device!(bus_pid) do
    i2c().write(bus_pid, <<@whoami_register>>)
    if i2c().read(bus_pid, 1) != <<@i2c_identifier>> do
      throw {__MODULE__, "Bad I2C device."}
    end
  end
end
