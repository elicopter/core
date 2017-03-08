defmodule Api.SensorsController do
  use Api.Web, :controller

  def index(conn, _params) do
    sensors = Brain.Sensors.Supervisor.registered_sensors() |> Enum.map(fn sensor ->
      %{
        configuration: GenServer.call(sensor, :configuration)
      }
    end)
    render conn, "index.json", %{sensors: sensors}
  end
end
