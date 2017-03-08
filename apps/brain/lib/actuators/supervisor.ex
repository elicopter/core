defmodule Brain.Actuators.Supervisor do
  use Supervisor
  require Logger

  def start_link() do
    Supervisor.start_link(__MODULE__, [])
  end

  def init([]) do
    children = registered_actuators() |> Enum.map(fn actuator_module ->
      actuator_configuration = Application.get_env(:brain, actuator_module)
      driver_module          = actuator_configuration[:driver]
      [
        supervisor(Drivers.Supervisor, [driver_module, Application.get_env(:brain, driver_module)], [id: driver_module]),
        worker(actuator_module, [driver_module])
      ]
    end) |> List.flatten
    supervise(children, strategy: :one_for_one)
  end

  def registered_actuators() do
    Application.get_env(:brain, :actuators)
  end
end
