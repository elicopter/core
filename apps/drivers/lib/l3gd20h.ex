defmodule Drivers.L3GD20H.State do
  defstruct [:bus_pid, :zero_rate_x_drift, :zero_rate_y_drift, :zero_rate_z_drift]
end

defmodule Drivers.L3GD20H do
  use Drivers.Common
  alias Drivers.L3GD20H.State

  @i2c_identifier 0xD7
  @whoami_register 0x0F
  @ctrl_reg1_register 0x20
  @ctrl_reg4_register 0x23
  @out_x_l_register 0x28
  @sensitivity 0.070
  @calibration_reads 5000

  def init([bus_pid, configuration]) do
    validate_i2c_device!(bus_pid)
    i2c().write(bus_pid, <<@ctrl_reg1_register, 0x0F>>)
    i2c().write(bus_pid, <<@ctrl_reg4_register, 0x20>>) # 2000 dps
    {:ok, %State{
        bus_pid: bus_pid,
        zero_rate_x_drift: configuration[:zero_rate_x_drift] || 0,
        zero_rate_y_drift: configuration[:zero_rate_y_drift] || 0,
        zero_rate_z_drift: configuration[:zero_rate_z_drift] || 0,
      }
    }
  end

  def start_link(bus_pid, configuration, opts \\ []) do
    Logger.debug "Starting #{__MODULE__}..."
    GenServer.start_link(__MODULE__, [bus_pid, configuration], opts)
  end

  def handle_call(:read, _from, state) do
    {:reply, read(state), state}
  end

  def handle_call(:calibrate, _from, %State{bus_pid: bus_pid} = state) do
    Logger.info "Calibrate #{__MODULE__}..."
    default_calibration_data = %{
      zero_rate_x_drift: 0,
      zero_rate_y_drift: 0,
      zero_rate_z_drift: 0
    }
    state = Map.merge(state, default_calibration_data)
    {:ok, calibration_data} = calibrate(state)
    Logger.info "Calibration successful for #{__MODULE__}..."
    IO.inspect calibration_data
    {:reply, {:ok, calibration_data}, Map.merge(state, calibration_data)}
  end

  defp calibrate(state), do: calibrate(state, @calibration_reads, [], [], [])
  defp calibrate(state, calibration_reads_remaining, xs, ys, zs) do
    case calibration_reads_remaining do
      0 ->
        {:ok, %{
            zero_rate_x_drift: Enum.reduce(xs, 0, fn(x, xs) -> x + xs end) / @calibration_reads,
            zero_rate_y_drift: Enum.reduce(ys, 0, fn(y, ys) -> y + ys end) / @calibration_reads,
            zero_rate_z_drift: Enum.reduce(zs, 0, fn(z, zs) -> z + zs end) / @calibration_reads
          }
        }
      _ ->
        {:ok, {x, y, z}} = raw_read(state)
        calibrate(state, calibration_reads_remaining - 1, [x | xs], [y | ys], [z | zs])
    end
  end

  defp read(state) do
    {:ok, {x, y, z}} = raw_read(state)
    # unit: "degrees per second"
    {:ok, %{
      x: ((x - state.zero_rate_x_drift) * @sensitivity),
      y: ((y - state.zero_rate_y_drift) * @sensitivity) ,
      z: ((z - state.zero_rate_z_drift) * @sensitivity),
      raw_x: (x - state.zero_rate_x_drift),
      raw_y: (y - state.zero_rate_y_drift),
      raw_z: (z - state.zero_rate_z_drift)
    }}
  end

  defp raw_read(%State{bus_pid: bus_pid} = state) do
    i2c().write(bus_pid, <<@out_x_l_register ||| 0x80>>)
    raw_data = i2c().read(bus_pid, 6)
    <<x :: signed-16>> = binary_part(raw_data, 1, 1) <> binary_part(raw_data, 0, 1)
    <<y :: signed-16>> = binary_part(raw_data, 3, 1) <> binary_part(raw_data, 2, 1)
    <<z :: signed-16>> = binary_part(raw_data, 5, 1) <> binary_part(raw_data, 4, 1)
    {:ok, {x, y, z}}
  end

  defp validate_i2c_device!(bus_pid) do
    i2c().write(bus_pid, <<@whoami_register>>)
    if i2c().read(bus_pid, 1) != <<@i2c_identifier>> do
      throw {__MODULE__, "Bad I2C device."}
    end
  end
end
