defmodule Api.StatusView do
  use Api.Web, :view

  def render("show.json", %{status: status}) do
    %{
      data: render_one(status, __MODULE__, "status.json", as: :status)
    }
  end

  def render("status.json", %{status: status}) do
    status
  end
end
