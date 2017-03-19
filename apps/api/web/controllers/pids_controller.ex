defmodule Api.PIDsController do
  use Api.Web, :controller

  @pids [Brain.PitchRatePIDController, Brain.RollRatePIDController, Brain.YawRatePIDController]

  def index(conn, _params) do
    pids = @pids |> Enum.reduce([], fn (pid_controller, acc) ->
      {:ok, snapshot} = Brain.PIDController.snapshot(pid_controller);
      [snapshot | acc]
    end)
    render conn, "index.json", %{pids: pids}
  end

  def show(conn, %{"name" => pid_controller_name}) do
    {:ok, snapshot} = Brain.PIDController.snapshot(Module.concat("Brain", pid_controller_name));
    render conn, "show.json", %{pid: snapshot}
  end

  def create(conn, %{"name" => pid_controller_name, "parameter" => parameter, "value" => value} = params) do
    :ok = GenServer.cast(Module.concat("Brain", pid_controller_name), {:tune, Map.put(%{}, parameter |> String.to_atom, value)});
    render conn, "create.json", %{}
  end
end
