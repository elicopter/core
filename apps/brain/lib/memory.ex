defmodule Brain.Memory do
  use GenServer
  require Logger

  def init(_) do
    {:ok, %{}}
  end

  def start_link() do
    Logger.debug "Starting #{__MODULE__}..."
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def handle_call({:store, data}, {from_pid, _from_reference}, state) do
    {:ok, file_path} = build_file_path_from_pid(from_pid)
    Logger.info("#{__MODULE__} try to store data at #{file_path}.")
    with {:ok, file}      <- File.open(file_path, [:write, :utf8]),
         {:ok, json_data} <- Poison.encode(data),
         :ok              <- IO.write(file, json_data) do
      Logger.info("#{__MODULE__} stored data into #{file_path}")
      {:reply, :ok, state}
    else {:error, :enoent} ->
      {:reply, {:error, :enoent}, state}
    end
  end

  def handle_call(:retreive, {from_pid, _from_reference}, state) do
    with {:ok, file_path}  <- build_file_path_from_pid(from_pid),
         {:ok, file}       <- File.open(file_path, [:read, :utf8]),
         json_data         <- IO.read(file, :all),
         {:ok, data}       <- Poison.decode(json_data) do
      Logger.info("#{__MODULE__} loaded data from #{file_path}")
      {:reply, {:ok, data}, state}
    else {:error, :enoent} ->
      {:reply, {:ok, nil}, state}
    end
  end

  def store(data) do
    GenServer.call(__MODULE__, {:store, data})
  end

  def retreive do
    GenServer.call(__MODULE__, :retreive)
  end

  defp build_file_path_from_pid(pid) do
    root_path       = Application.get_env(:brain, __MODULE__)[:root_path]
    registered_name = Process.info(pid)[:registered_name] |> Macro.underscore |> String.replace("/", "__")
    file_path       = root_path <> "/" <> registered_name <> ".json"
    {:ok, file_path}
  end
end

