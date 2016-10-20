defmodule Sensor.L3GD20H do
  use GenServer
  use Bitwise
  require Logger

  @i2c Application.get_env(:core, :i2c)

  @i2c_address 0x6B
  @i2c_identifier 0xD7
  @whoami_register 0x0F
  @ctrl_reg1_register 0x20
  @ctrl_reg4_register 0x23
  @out_x_l_register 0x28
  @sensitivity 0.0175

  def init({i2c_pid}) do
    validate_i2c_device!(i2c_pid)
    @i2c.write_device(i2c_pid, @i2c_address, <<@ctrl_reg1_register, 0xFF>>) # 800 hz
    @i2c.write_device(i2c_pid, @i2c_address, <<@ctrl_reg4_register, 0x10>>) # 500 dps
    {:ok, %{i2c_pid: i2c_pid, data: %{x: nil, y: nil, z: nil}}}
  end

  def start_link(i2c_pid, name \\ :gyroscope) do
    Logger.debug "Starting #{__MODULE__}..."
    GenServer.start_link(__MODULE__, {i2c_pid}, name: name)
  end

  def handle_call(:read, _from, state) do
    i2c_pid = state[:i2c_pid]
    @i2c.write_device(i2c_pid, @i2c_address, <<@out_x_l_register ||| 0x80>>)
    raw_data = @i2c.read_device(i2c_pid, @i2c_address, 6)
    <<x :: signed-16>> = binary_part(raw_data, 1, 1) <> binary_part(raw_data, 0, 1)
    <<y :: signed-16>> = binary_part(raw_data, 3, 1) <> binary_part(raw_data, 2, 1)
    <<z :: signed-16>> = binary_part(raw_data, 5, 1) <> binary_part(raw_data, 4, 1)
    # unit: "degrees per second"
    data = %{
      x: x * @sensitivity,
      y: y * @sensitivity,
      z: z * @sensitivity
    }
    {:reply, data, %{state | data: data}}
  end

  defp validate_i2c_device!(i2c_pid) do
    @i2c.write_device(i2c_pid, @i2c_address, <<@whoami_register>>)
    if @i2c.read_device(i2c_pid, @i2c_address, 1) != <<@i2c_identifier>> do
      throw {__MODULE__, "Bad I2C device."}
    end
  end

  def read(pid \\ :gyroscope) do
    GenServer.call(pid, :read)
  end
end
