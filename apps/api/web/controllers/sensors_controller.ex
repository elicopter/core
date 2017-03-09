defmodule Api.SensorsController do
  use Api.Web, :controller

  def index(conn, _params) do
    sensors = Brain.Sensors.Supervisor.registered_sensors() |> Enum.map(fn sensor ->
      {:ok, value} = GenServer.call(sensor, :read)
      IO.inspect value
      %{
        name:          sensor,
        configuration: GenServer.call(sensor, :configuration),
        value:         value
      }
    end)
    render conn, "index.json", %{sensors: sensors}
  end
end
