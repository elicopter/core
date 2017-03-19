defmodule Api.Router do
  use Api.Web, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", Api do
    pipe_through :api

    get "/", HomeController, :index
    get "/sensors", SensorsController, :index
    get "/pids", PIDsController, :index
    get "/pids/:name", PIDsController, :show
    get "/snapshot", SnapshotController, :show
    get "/status", StatusController, :show
  end
end
