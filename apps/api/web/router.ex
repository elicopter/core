defmodule Api.Router do
  use Api.Web, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", Api do
    pipe_through :api

    get "/", HomeController, :index
    get "/sensors", SensorsController, :index
    get "/snapshot", SnapshotsController, :show
  end
end
