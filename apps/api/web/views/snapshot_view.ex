defmodule Api.SnapshotView do
  use Api.Web, :view

  def render("show.json", %{snapshot: snapshot}) do
    %{
      data: render_one(snapshot, __MODULE__, "snapshot.json", as: :snapshot)
    }
  end

  def render("snapshot.json", %{snapshot: snapshot}) do
    %{
      interpreter:                snapshot[:interpreter],
      yaw_rate_pid_controller:    snapshot[:yaw_rate_pid_controller],
      roll_rate_pid_controller:   snapshot[:roll_rate_pid_controller],
      yaw_rate_pid_controller:    snapshot[:roll_rate_pid_controller],
      pitch_angle_pid_controller: snapshot[:pitch_angle_pid_controller],
      roll_angle_pid_controller:  snapshot[:roll_angle_pid_controller],
      mixer:                      snapshot[:mixer],
      loop:                       snapshot[:loop]
    }
  end
end
