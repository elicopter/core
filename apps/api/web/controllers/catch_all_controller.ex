defmodule Api.CatchAllController do
  use Api.Web, :controller

  def index(conn, _params) do
    conn |> put_status(404) |> json(nil)
  end
end
