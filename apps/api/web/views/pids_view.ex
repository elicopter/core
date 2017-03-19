defmodule Api.PIDsView do
  use Api.Web, :view

  def render("index.json", %{pids: pids}) do
    %{
      data: render_many(pids, __MODULE__, "pid.json", as: :pid)
    }
  end

  def render("show.json", %{pid: pid}) do
    %{
      data: render_one(pid, __MODULE__, "pid.json", as: :pid)
    }
  end

  def render("create.json", %{}) do
    %{}
  end

  def render("pid.json", %{pid: pid}) do
    pid
  end
end
