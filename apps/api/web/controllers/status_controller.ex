defmodule Api.StatusController do
  use Api.Web, :controller

  def show(conn, _params) do
    {:ok, status} = Brain.BlackBox.status()
    render conn, "show.json", %{status: status}
  end
end
