defmodule Brain.Sensors.Supervisor do
  use Supervisor
  require Logger

  def start_link() do
    Supervisor.start_link(__MODULE__, [])
  end

  def init([]) do
    children = registered_sensors() |> Enum.map(fn sensor_module ->
      sensor_configuration = Application.get_env(:brain, sensor_module)
      driver_module        = sensor_configuration[:driver]
      [
        supervisor(Drivers.Supervisor, [driver_module, Application.get_env(:brain, driver_module)], [id: driver_module]),
        worker(sensor_module, [driver_module])
      ]
    end) |> List.flatten
    supervise(children, strategy: :one_for_one)
  end

  def registered_sensors() do
    Application.get_env(:brain, :sensors)
  end
end
