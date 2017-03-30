defmodule Api.Router do
  use Api.Web, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", Api do
    pipe_through :api

    get "/", HomeController, :index
    resources "/sensors", SensorsController, only: [:index]
    resources "/pids", PIDsController, only: [:index, :show, :create]
    resources "/recorded-loops-files", RecordedLoopsFilesController, only: [:index, :show], param: "name"

    get "/snapshot", SnapshotController, :show
    get "/status", StatusController, :show
  end
end
