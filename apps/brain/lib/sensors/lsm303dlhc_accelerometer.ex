defmodule Sensor.LSM303DLHCAccelerometer do
  use GenServer
  use Bitwise
  require Logger

  @i2c Application.get_env(:brain, :i2c)

  @i2c_address 0x19
  @rate 0x97 # 1344 Hz in Normal mode
  @ctrl_register_1 0x20
  @sensitivity 0.001
  @out_x_l_register 0x28

  def init({i2c_pid}) do
    @i2c.write_device(i2c_pid, @i2c_address, <<@ctrl_register_1, @rate>>)
    validate_i2c_device!(i2c_pid)
    {:ok, %{
        i2c_pid: i2c_pid
      }
    }
  end

  def start_link(i2c_pid, name \\ :accelerometer) do
    Logger.debug "Starting #{__MODULE__}..."
    GenServer.start_link(__MODULE__, {i2c_pid}, name: name)
  end

  def handle_call(:read, _from, %{i2c_pid: i2c_pid} = state) do
    @i2c.write_device(i2c_pid, @i2c_address, <<@out_x_l_register ||| 0x80>>)
    raw_data = @i2c.read_device(i2c_pid, @i2c_address, 6)
    <<x :: signed-16>> = (binary_part(raw_data, 1, 1) <> binary_part(raw_data, 0, 1))
    <<y :: signed-16>> = (binary_part(raw_data, 3, 1) <> binary_part(raw_data, 3, 1))
    <<z :: signed-16>> = (binary_part(raw_data, 5, 1) <> binary_part(raw_data, 4, 1))
    # unit: "g"
    data = %{
      x: (x >>> 4) * @sensitivity,
      y: (y >>> 4) * @sensitivity,
      z: (z >>> 4) * @sensitivity
    }
    {:reply, data, state}
  end

  def read(pid \\ :accelerometer) do
    GenServer.call(pid, :read)
  end

  defp validate_i2c_device!(i2c_pid) do
    @i2c.write_device(i2c_pid, @i2c_address, <<@ctrl_register_1>>)
    <<value :: unsigned-8>> = @i2c.read_device(i2c_pid, @i2c_address, 1)
    if value != @rate do
      throw {__MODULE__, "Bad I2C device."}
    end
  end
end
