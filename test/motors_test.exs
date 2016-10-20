defmodule MotorsTest do
  use ExUnit.Case, async: true

  @i2c Application.get_env(:core, :i2c)
  @pwm Application.get_env(:core, :motor_pwm)

  setup do
    @i2c.set_listener(self(), :motor_pwm_i2c)
    :ok
  end

  test "bounds throttle values when they are too high (greater than max value)", _ do
    {:ok, [first_higher_value, second_higher_value, _, _]} = Motors.throttles(["1": 6000, "2": 9999, "3": 0 , "4": 100])
    assert first_higher_value >= Motors.minimum_pwm_value
    assert second_higher_value >= Motors.minimum_pwm_value
    assert_received {:write, <<6, 0, 0, 160, 15, 0, 0, 160, 15, 0, 0, 76, 4, 0, 0, 110, 5>>}, 5
  end

  test "compensates throttle values when they are too low (smaller than min value)", _ do
    {:ok, [first_lower_value, second_lower_value, _, _]} = Motors.throttles(["1": -6000, "2": -9999, "3": 0 , "4": 100])
    assert first_lower_value >= Motors.minimum_pwm_value
    assert second_lower_value >= Motors.minimum_pwm_value
    assert_received {:write, <<6, 0, 0, 76, 4, 0, 0, 76, 4, 0, 0, 76, 4, 0, 0, 110, 5>>}, 5
  end
end
