defmodule Drivers.Supervisor do
  use Supervisor
  require Logger

  def start_link(driver_module, configuration) do
    Supervisor.start_link(__MODULE__, [driver_module, configuration])
  end

  def init([driver_module, configuration]) do
    driver_bus_name = Module.concat(driver_module, "Bus")
    bus_worker      = bus_worker(configuration, driver_bus_name)
    children        = [
      bus_worker,
      worker(driver_module, [driver_bus_name, configuration, [name: driver_module]])
    ]
    Logger.debug "Starting #{driver_module}..."
    supervise(children, strategy: :one_for_one)
  end

  def bus_worker(configuration, driver_bus_name) do
    case configuration[:bus] do
      :i2c ->
        worker(Application.get_env(:drivers, :i2c), [configuration[:bus_name], configuration[:address] || 0x00, [name: driver_bus_name]])
      :uart ->
        worker(Application.get_env(:drivers, :uart), [[name: driver_bus_name]])
      nil ->
        raise "You need to specify a bus in your configuration file."
      _ ->
        raise "Unknown bus."
      end
  end
end
