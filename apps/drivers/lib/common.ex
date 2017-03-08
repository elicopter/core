defmodule Drivers.Common do
  defmacro __using__(_opts) do
    quote do
      import Drivers.Common
      alias Drivers.State
      use GenServer
      use Bitwise

      def i2c() do
        Application.get_env(:drivers, :i2c)
      end
    end
  end
end
