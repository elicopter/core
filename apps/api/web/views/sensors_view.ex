defmodule Api.SensorsView do
  use Api.Web, :view

  def render("index.json", %{sensors: sensors}) do
    %{
      data: render_many(sensors, __MODULE__, "sensor.json", as: :sensor)
    }
  end

  def render("sensor.json", %{sensor: sensor}) do
    sensor
  end
end
