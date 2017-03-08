defmodule Drivers.Supervisor do
  use Supervisor
  require Logger

  def start_link(driver_module) do
    Supervisor.start_link(__MODULE__, [driver_module])
  end

  def init([driver_name]) do
    driver_module   = Module.concat(Module.concat("Elixir", "Drivers"), driver_name)
    driver_bus_name = Module.concat(driver_module, "Bus")
    configuration   = driver_configuration(driver_name)
    children = [
      worker(bus_module(configuration[:bus]), [configuration[:bus_name], configuration[:address] || 0x00, [name: driver_bus_name]]),
      worker(driver_module, [driver_bus_name, configuration, [name: driver_module]])
    ]
    Logger.debug "Starting #{driver_name} as #{driver_module}..."
    supervise(children, strategy: :one_for_one)
  end

  def driver_configuration(driver_name) do
    Application.get_env(:drivers, driver_name |> String.downcase |> String.to_existing_atom)
  end

  def bus_module(bus) do
    case bus do
      :i2c ->
        Application.get_env(:drivers, :i2c)
      :uart ->
        Application.get_env(:drivers, :uart)
      nil ->
        raise "You need to specify a bus in your configuration file."
      _ ->
        raise "Unknown #{bus} bus."
      end
  end
end
