defmodule Drivers.LSM303DLHCAccelerometer do
  use Drivers.Common

  @rate 0x97 # 1344 Hz in Normal mode
  @ctrl_register_1 0x20
  @ctrl_register_4 0x23
  @ctrl_register_5 0x24
  @sensitivity 0.001
  @out_x_l_register 0x28
  @fullscale_4g 0x10
  @gravity 9.80665

  def init([bus_pid, configuration]) do
    i2c().write(bus_pid, <<@ctrl_register_5, 0x80>>)
    Process.sleep(100)
    i2c().write(bus_pid, <<@ctrl_register_1, @rate>>)
    Process.sleep(10)
    i2c().write(bus_pid, <<@ctrl_register_4, @fullscale_4g>>)
    Process.sleep(100)
    validate_i2c_device!(bus_pid)
    {:ok, %State{bus_pid: bus_pid, configuration: configuration}}
  end

  def start_link(bus_pid, configuration, opts \\ []) do
    Logger.debug "Starting #{__MODULE__}..."
    GenServer.start_link(__MODULE__, [bus_pid, configuration], opts)
  end

  def handle_call(:read, _from, %State{bus_pid: bus_pid} = state) do
    i2c().write(bus_pid, <<@out_x_l_register ||| 0x80>>)
    raw_data = i2c().read(bus_pid, 6)
    <<x :: signed-16>> = (binary_part(raw_data, 1, 1) <> binary_part(raw_data, 0, 1))
    <<y :: signed-16>> = (binary_part(raw_data, 3, 1) <> binary_part(raw_data, 3, 1))
    <<z :: signed-16>> = (binary_part(raw_data, 5, 1) <> binary_part(raw_data, 4, 1))
    # unit: "g"
    data = %{
      x: (x >>> 4) * @sensitivity,
      y: (y >>> 4) * @sensitivity,
      z: (z >>> 4) * @sensitivity
    }
    {:reply, {:ok, data}, state}
  end

  defp validate_i2c_device!(bus_pid) do
    i2c().write(bus_pid, <<@ctrl_register_1>>)
    <<value :: unsigned-8>> = i2c().read(bus_pid, 1)
    if value != @rate do
      throw {__MODULE__, "Bad I2C device."}
    end
  end
end
