defmodule Drivers.Common do
  defmacro __using__(_opts) do
    quote do
      import Drivers.Common
      alias Drivers.State
      use GenServer
      use Bitwise
    end
  end
end
