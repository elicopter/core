defmodule Api do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      supervisor(Api.Endpoint, [])
    ]

    opts = [strategy: :one_for_one, name: Api.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def config_change(changed, _new, removed) do
    Api.Endpoint.config_change(changed, removed)
    :ok
  end
end
