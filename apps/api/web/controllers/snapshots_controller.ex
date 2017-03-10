defmodule Api.SnapshotsController do
  use Api.Web, :controller

  def show(conn, _params) do
    {:ok, snapshot} = Brain.BlackBox.snapshot()
    render conn, "show.json", %{snapshot: snapshot}
  end
end
