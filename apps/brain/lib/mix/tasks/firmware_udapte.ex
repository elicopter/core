defmodule Mix.Tasks.Firmware.Update do
  use Mix.Task
  require Logger
  def run(_) do
    {:ok, _pid}       = HTTPoison.start
    {:ok, _pid}       = Nerves.SSDPClient.start(nil, nil)
    {:ok, elicopters} = discover()
    # Need to handle multiple nodes
    {elicopter_name, elicopter_info} = elicopters |> List.first
    Logger.info("Found #{elicopter_name} at #{elicopter_info[:host]}.")
    build()
    upload(elicopter_info[:host])
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
    HTTPoison.request!(:post, firmware_update_url, {:file, firmware_path}, [{"Content-Type", "application/x-firmware"}, {"X-Reboot", "true"}], [timeout: 30000, recv_timeout: 30000])
    # HTTPoison.post!(firmware_update_url, {:file, firmware_path}, [{"Content-Type", "application/x-firmware"}, {"X-Reboot", "true"}])
  end
end