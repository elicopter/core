defmodule Sensor.LSM303DLHCMagnetometer do
  use GenServer
  use Bitwise
  require Logger

  @i2c Application.get_env(:brain, :i2c)

  @i2c_address 0x1E
  @rate 0x10 # 15hz may need to increase
  @cra_register 0x00
  @crb_register 0x01
  @mr_register 0x02
  @x_y_gain 1100
  @z_gain 980
  @out_x_h_register 0x03
  @gauss_to_micro_tesla_multiplier 100

  def init({i2c_pid}) do
    @i2c.write_device(i2c_pid, @i2c_address, <<@mr_register, 0x00>>)
    validate_i2c_device!(i2c_pid)
    {:ok, %{
        i2c_pid: i2c_pid
      }
    }
  end

  def start_link(i2c_pid, name \\ :magnetometer) do
    Logger.debug "Starting #{__MODULE__}..."
    GenServer.start_link(__MODULE__, {i2c_pid}, name: name)
  end

  def handle_call(:read, _from, %{i2c_pid: i2c_pid} = state) do
    @i2c.write_device(i2c_pid, @i2c_address, <<@out_x_h_register ||| 0x80>>)
    raw_data = @i2c.read(i2c_pid, 6)
    <<x :: signed-16>> = (binary_part(raw_data, 0, 1) <> binary_part(raw_data, 1, 1))
    <<y :: signed-16>> = (binary_part(raw_data, 2, 1) <> binary_part(raw_data, 3, 1))
    <<z :: signed-16>> = (binary_part(raw_data, 4, 1) <> binary_part(raw_data, 5, 1))
    # unit: "micro tesla"
    data = %{
      x: x / @x_y_gain * @gauss_to_micro_tesla_multiplier,
      y: y / @x_y_gain * @gauss_to_micro_tesla_multiplier,
      z: z / @z_gain * @gauss_to_micro_tesla_multiplier
    }
    {:reply, data, state}
  end

  defp validate_i2c_device!(i2c_pid) do
    @i2c.write_device(i2c_pid, @i2c_address, <<@cra_register>>)
    <<value :: unsigned-8>> = @i2c.read_device(i2c_pid, @i2c_address, 1)
    if value != @rate do
      throw {__MODULE__, "Bad I2C device."}
    end
  end

  def read(pid \\ :magnetometer) do
    GenServer.call(pid, :read)
  end
end
