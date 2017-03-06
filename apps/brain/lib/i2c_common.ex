defmodule I2CCommon do
  use Bitwise

  @i2c Application.get_env(:brain, :i2c)

  def read_at(type, pid, i2c_address, address \\ nil) do
    unless address == nil, do: @i2c.write_device(pid, i2c_address, <<address>>)
    case type do
      :signed_8 ->
        <<value :: signed-8>> = @i2c.read_device(pid, i2c_address, 1)
        value
      :unsigned_8 ->
        <<value :: unsigned-8>> = @i2c.read_device(pid, i2c_address, 1)
        value
      :signed_16 ->
        <<value :: signed-16>> = @i2c.read_device(pid, i2c_address, 2)
        value
      :unsigned_16 ->
        <<value :: unsigned-16>> = @i2c.read_device(pid, i2c_address, 2)
        value
      :signed_24 ->
        <<value :: signed-24>> = @i2c.read_device(pid, i2c_address, 3)
        value
      :unsigned_24 ->
        <<value :: unsigned-24>> = @i2c.read_device(pid, i2c_address, 3)
        value
      :little_unsigned_16 ->
        <<value :: little-unsigned-16>> = @i2c.read_device(pid, i2c_address, 2)
        value
      :little_signed_16 ->
        <<value :: little-signed-16>> = @i2c.read_device(pid, i2c_address, 2)
        value
    end
  end

  defmacro __using__(_opts) do
    quote do
      import I2CCommon
    end
  end
end
