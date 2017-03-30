defmodule Api.RecordedLoopsFilesView do
  use Api.Web, :view

  def render("index.json", %{recorded_loops_files: recorded_loops_files}) do
    %{
      data: render_many(recorded_loops_files, __MODULE__, "recorded_loops_file.json", as: :recorded_loops_file)
    }
  end

  def render("recorded_loops_file.json", %{recorded_loops_file: recorded_loops_file}) do
    %{
      name: recorded_loops_file[:name],
      size: %{
        bytes:     recorded_loops_file[:size],
        kilobytes: recorded_loops_file[:size] / 1024,
        megabytes: recorded_loops_file[:size] / 1024 / 1024
      },
      url:  recorded_loops_file[:url]
    }
  end
end
