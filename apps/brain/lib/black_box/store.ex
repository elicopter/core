defmodule Brain.BlackBox.Store do
  use GenServer
  require Logger

  def init(_) do
    remove_all_old_recorded_loops_files()
    {:ok, %{recorded_loops_file: nil}}
  end

  def start_link do
    Logger.debug "Starting #{__MODULE__}..."
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def handle_cast({:start_recording_loops, last_loop}, state) do
    with {:ok, file_path} <- build_recorded_loops_file_path(),
         {:ok, file}      <- File.open(file_path, [:write]) do
      headers = Enum.map(last_loop, fn({_key, {data, module}}) ->
        {:ok, csv} = module.csv_headers(data)
        csv
      end)
      |> Enum.join(",")
      IO.binwrite(file, headers <> "\n")
      {:noreply, %{state | recorded_loops_file: file}}
    end
  end

  def handle_cast(:stop_recording_loops, %{recorded_loops_file: recorded_loops_file} = state) do
    File.close(recorded_loops_file)
    Logger.debug("#{__MODULE__} all recorded loops are stored.")
    {:noreply, %{state | recorded_loops_file: nil}}
  end

  def handle_cast({:store_recorded_loops_in_csv, last_loops}, %{recorded_loops_file: recorded_loops_file} = state) do
    last_loops_csv_string = last_loops
    |> Enum.map(&loop_to_csv(&1))
    |> Enum.join("\n")
    IO.binwrite(recorded_loops_file, last_loops_csv_string)
    {:noreply, state}
  end
  def recorded_loops_path do
    Application.get_env(:brain, Brain.BlackBox)[:root_path]
  end

  defp build_recorded_loops_file_path do
    {uptime, _} = :erlang.statistics(:wall_clock)
    file_path   = recorded_loops_path() <> "/loop_" <> Integer.to_string(uptime) <> ".csv"
    {:ok, file_path}
  end

  defp remove_all_old_recorded_loops_files do
    File.rm_rf(recorded_loops_path())
    File.mkdir(recorded_loops_path())
  end

  defp loop_to_csv(loop) do
    Enum.map(loop, fn({_key, {data, module}}) ->
      {:ok, data_csv} = module.to_csv(data)
      data_csv
    end) |> Enum.join(",")
  end
end