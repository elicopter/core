defmodule Drivers.Supervisor do
  use Supervisor
  require Logger

  def start_link(driver_module) do
    Supervisor.start_link(__MODULE__, [driver_module])
  end

  def init([driver_name]) do
    driver_module = Module.concat(Module.concat("Elixir", "Drivers"), driver_name)
    driver_bus    = Module.concat(driver_module, "Bus")
    configuration = driver_configuration(driver_name)
    children = [
      worker(Dummy.I2c, [configuration[:bus_name], configuration[:address], [name: driver_bus]]),
      worker(driver_module, [driver_bus, [name: driver_module]])
    ]
    Logger.debug "Starting #{driver_name} as #{driver_module}..."
    supervise(children, strategy: :one_for_one)
  end

  def driver_configuration(driver_name) do
    Application.get_env(:drivers, driver_name |> String.downcase |> String.to_existing_atom)
  end
end
