defmodule Mix.Tasks.Firmware.Update do
   use Mix.Task
   require Logger

   def run(_) do
      HTTPoison.start
      Logger.info("Build firmware...")
      Mix.Task.run("firmware")
      firmware_base_url   = Application.get_env(:brain, :firmware_http)[:url]
      firmware_path       = Path.absname("_images/rpi3/brain.fw")
      firmware_update_url = URI.merge(firmware_base_url, "/firmware") |> URI.to_string()
      IO.inspect firmware_update_url
      Logger.info("Update firmware to #{firmware_base_url}...")
      HTTPoison.post!(firmware_update_url, {:file, firmware_path}, [{"Content-Type", "application/x-firmware"}, {"X-Reboot", "true"}])
   end
end
