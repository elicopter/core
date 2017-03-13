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
  @sensitivity 0.0175
  @calibration_reads 5000

  def init([bus_pid, configuration]) do
    validate_i2c_device!(bus_pid)
    i2c().write(bus_pid, <<@ctrl_reg1_register, 0xFF>>) # 800 hz
    i2c().write(bus_pid, <<@ctrl_reg4_register, 0x10>>) # 500 dps
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
        {:ok, %{x: x, y: y, z: z}} = read(state)
        calibrate(state, calibration_reads_remaining - 1, [x | xs], [y | ys], [z | zs])
    end
  end

  defp read(%State{bus_pid: bus_pid} = state) do
    i2c().write(bus_pid, <<@out_x_l_register ||| 0x80>>)
    raw_data = i2c().read(bus_pid, 6)
    <<x :: signed-16>> = binary_part(raw_data, 1, 1) <> binary_part(raw_data, 0, 1)
    <<y :: signed-16>> = binary_part(raw_data, 3, 1) <> binary_part(raw_data, 2, 1)
    <<z :: signed-16>> = binary_part(raw_data, 5, 1) <> binary_part(raw_data, 4, 1)
    # unit: "degrees per second"
    {:ok, %{
      x: (x * @sensitivity) - state.zero_rate_x_drift,
      y: (y * @sensitivity) - state.zero_rate_y_drift,
      z: (z * @sensitivity) - state.zero_rate_z_drift
    }}
  end

  defp validate_i2c_device!(bus_pid) do
    i2c().write(bus_pid, <<@whoami_register>>)
    if i2c().read(bus_pid, 1) != <<@i2c_identifier>> do
      throw {__MODULE__, "Bad I2C device."}
    end
  end
end
