defmodule Sensor.BMP180 do
  use GenServer
  use Bitwise
  use I2CCommon
  require Logger
  require Apex

  @i2c Application.get_env(:core, :i2c)

  @i2c_address 0x77
  @i2c_identifier 0x55
  @whoami_register 0xD0
  @ultrahigh_resolution_mode 3
  @measurement_control_register 0xF4
  @pressure_data_register 0xF6
  @temperature_data_register 0xF6
  @read_temperature_command 0x2E
  @read_pressure_command 0x34
  @ac1_register 0xAA
  @ac2_register 0xAC
  @ac3_register 0xAE
  @ac4_register 0xB0
  @ac5_register 0xB2
  @ac6_register 0xB4
  @b1_register 0xB6
  @b2_register 0xB8
  @mb_register 0xBA
  @mc_register 0xBC
  @md_register 0xBE

  def init({i2c_pid}) do
    validate_i2c_device!(i2c_pid)
    calibration_data = read_calibration_data(i2c_pid)
    {:ok, %{
        i2c_pid: i2c_pid,
        mode: @ultrahigh_resolution_mode,
        data: %{},
        meta: %{
          calibration: calibration_data
        }
      }
    }
  end

  def start_link(i2c_pid, name \\ :barometer) do
    Logger.debug "Starting #{__MODULE__}..."
    GenServer.start_link(__MODULE__, {i2c_pid}, name: name)
  end

  def handle_call(:read, _from, state) do
    ut               = read_uncompensated_temperature(state)
    up               = read_uncompensated_pressure(state)
    temperature_data = compute_temperature(ut, state[:meta][:calibration])
    pressure         = compute_pressure(up, temperature_data[:b5], state[:mode], state[:meta][:calibration])

    # pressure_unit: "pascal",
    # temperature_unit: "celsius"
    data = %{
      temperature: temperature_data[:t] * 0.1,
      pressure: pressure
    }
    {:reply, data, %{state | data: data}}
  end

  defp read_calibration_data(i2c_pid) do
    %{
      ac1: read_at(:signed_16, i2c_pid, @i2c_address, @ac1_register),
      ac2: read_at(:signed_16, i2c_pid, @i2c_address, @ac2_register),
      ac3: read_at(:signed_16, i2c_pid, @i2c_address, @ac3_register),
      ac4: read_at(:unsigned_16, i2c_pid, @i2c_address, @ac4_register),
      ac5: read_at(:unsigned_16, i2c_pid, @i2c_address, @ac5_register),
      ac6: read_at(:unsigned_16, i2c_pid, @i2c_address, @ac6_register),
      b1: read_at(:signed_16, i2c_pid, @i2c_address, @b1_register),
      b2: read_at(:signed_16, i2c_pid, @i2c_address, @b2_register),
      mb: read_at(:signed_16, i2c_pid, @i2c_address, @mb_register),
      mc: read_at(:signed_16, i2c_pid, @i2c_address, @mc_register),
      md: read_at(:signed_16, i2c_pid, @i2c_address, @md_register)
    }
  end

  defp read_uncompensated_pressure(state) do
    i2c_pid = state[:i2c_pid]
    command = @read_pressure_command + (state[:mode] <<< 6)
    @i2c.write_device(i2c_pid, @i2c_address, <<@measurement_control_register, command>>)
    :timer.sleep(25)
    read_at(:unsigned_24, i2c_pid, @i2c_address, @pressure_data_register) >>> 8 - state[:mode]
  end

  defp read_uncompensated_temperature(state) do
    i2c_pid = state[:i2c_pid]
    @i2c.write_device(i2c_pid, @i2c_address, <<@measurement_control_register, @read_temperature_command>>)
    :timer.sleep(5)
    read_at(:unsigned_16, i2c_pid, @i2c_address, @temperature_data_register)
  end

  defp compute_temperature(ut, calibration_data) do
    ac5 = calibration_data[:ac5]
    ac6 = calibration_data[:ac6]
    mc  = calibration_data[:mc]
    md  = calibration_data[:md]
    x1  = ((ut - ac6) * ac5) / :math.pow(2, 15)
    x2  = (mc * :math.pow(2, 11)) / (x1 + md)
    b5  = x1 + x2
    t   = ((b5 + 8) / :math.pow(2, 4))
    %{
      b5: b5,
      t: t
    }
  end

  defp compute_pressure(up, b5, mode, calibration_data) do
    b5 = round(b5)
    b6 = b5 - 4000
    x1 = (calibration_data[:b2] * (b6 * b6 / :math.pow(2, 12))) / :math.pow(2, 11)
    x2 = calibration_data[:ac2] * b6 / :math.pow(2, 11)
    x3 = x1 + x2 |> round
    b3 = (((calibration_data[:ac1] * 4 + x3) <<< mode) + 2) / 4
    x1 = calibration_data[:ac3] * b6 / :math.pow(2, 13)
    x2 = (calibration_data[:b1] * (b6 * b6 / :math.pow(2, 12))) / :math.pow(2, 16)
    x3 = ((x1 + x2) + 2) / :math.pow(2, 2)
    b4 = calibration_data[:ac4] * (x3 + 32_768) / :math.pow(2, 15)
    b7 = (up - b3) * (50_000 >>> mode)
    p = case b7 < 0x80000000 do
      true -> (b7 * 2) / b4
      false -> (b7 / b4) * 2
    end
    x1 = (p / :math.pow(2, 8)) * (p / :math.pow(2, 8))
    x1 = (x1 * 3038) / :math.pow(2, 16)
    x2 = (-7357 * p) / :math.pow(2, 16)
    p + (x1 + x2 + 3791) / :math.pow(2, 4)
  end

  defp validate_i2c_device!(i2c_pid) do
    @i2c.write_device(i2c_pid, @i2c_address, <<@whoami_register>>)
    if @i2c.read_device(i2c_pid, @i2c_address, 1) != <<@i2c_identifier>> do
      throw {__MODULE__, "Bad I2C device."}
    end
  end

  def read(pid \\ :barometer) do
    GenServer.call(pid, :read)
  end

end
