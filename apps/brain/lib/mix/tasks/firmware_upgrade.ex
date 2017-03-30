defmodule Mix.Tasks.Firmware.Upgrade do
  use Mix.Task
  require Logger
  def run(_) do
    {:ok, _pid}       = HTTPoison.start
    {:ok, _pid}       = Nerves.SSDPClient.start(nil, nil)
    host = case System.get_env("ELICOPTER_REMOTE_HOST") do
      nil ->
        {:ok, elicopters} = discover()
        # Need to handle multiple nodes
        {elicopter_name, elicopter_info} = elicopters |> List.first
        Logger.info("Found #{elicopter_name} at #{elicopter_info[:host]}.")
        elicopter_info[:host]
      host -> host
    end
    build()
    upload(host)
    Logger.info("Firmware updated!")
  end

  defp discover do
    Logger.info("Discovering Elicopters...")
    nodes      = Nerves.SSDPClient.discover
    elicopters = nodes |> Enum.filter(fn ({_name, info}) -> 
      case info do
        %{host: _, st: "elicopter"} -> true
        _ -> false
      end
    end)
    {:ok, elicopters}
  end
   
  defp build do
    Logger.info("Build firmware...")
    Mix.Task.run("firmware")
  end

  defp upload(host) do
    Logger.info("Upload firmware...")
    firmware_update_url = "http://#{host}:8988/firmware"
    firmware_path       = Path.absname("_images/rpi3/brain.fw")
    HTTPoison.request!(
      :post, firmware_update_url, {:file, firmware_path},
      [{"Content-Type", "application/x-firmware"}, {"X-Reboot", "true"}],
      [timeout: 30_000, recv_timeout: 30_000]
    )
  end
end