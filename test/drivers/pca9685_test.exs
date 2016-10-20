defmodule Driver.PCA9685Test do
  use ExUnit.Case, async: true
  alias Driver.PCA9685

  @i2c Application.get_env(:core, :i2c)

  setup do
    @i2c.set_listener(self(), :motor_pwm_i2c)
    {:ok, pid: :motor_pwm}
  end

  test "set pwm for all outputs (0->4)", %{pid: pid} do
    PCA9685.write([1, 255, 2, 65535], pid)
    assert_received {:write, <<6, 0, 0, 1, 0, 0, 0, 255, 0, 0, 0, 2, 0, 0, 0, 255, 255>>}, 5
  end

  test "set pwm for single output (1)", %{pid: pid} do
    PCA9685.write(1, 100, 200, pid)
    assert_received {:write, <<10, 100, 0, 200, 0>>}, 5
  end
end
