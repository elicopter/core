defmodule Api.RecordedLoopsFilesController do
  use Api.Web, :controller
  import Api.Router.Helpers

  def index(conn, _params) do
    {:ok, recorded_loops_files} = File.ls(Brain.BlackBox.Store.recorded_loops_path())
    recorded_loops_files = recorded_loops_files |> Enum.map(fn recorded_loops_filename ->
      %{
        name: recorded_loops_filename,
        size: case File.stat(recorded_loops_filepath(recorded_loops_filename)) do
          {:ok, %{size: size}} -> size
          {:error, reason}     -> -1
        end,
        url: recorded_loops_files_url(Api.Endpoint, :show, recorded_loops_filename)
      }
    end)
    render conn, "index.json", %{recorded_loops_files: recorded_loops_files}
  end

  def show(conn, %{"name" => recorded_loops_filename}) do
    conn
    |> put_resp_header("content-type", "text/csv")
    |> send_file(200, recorded_loops_filepath(recorded_loops_filename))
  end

  defp recorded_loops_filepath(recorded_loops_filename) do
    Brain.BlackBox.Store.recorded_loops_path() <> "/" <> recorded_loops_filename
  end
end
