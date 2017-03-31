defmodule Brain do
  use Application
  require Logger
  alias Brain.{ Receiver, Mixer, BlackBox, Loop, Memory, Interpreter, PIDController, Neopixel }

  @filter Application.get_env(:brain, :filter)
  @kernel_modules Mix.Project.config[:kernel_modules] || []

  def start(_type, _args) do
    import Supervisor.Spec
    children = [
      worker(Task, [fn -> init_kernel_modules() end], restart: :transient, id: Nerves.Init.KernelModules),
      worker(Task, [fn -> start_network() end], restart: :transient, id: Brain.Network),
      supervisor(Memory, []),
      supervisor(Brain.Sensors.Supervisor, []),
      supervisor(Brain.Actuators.Supervisor, []),
      supervisor(Drivers.Supervisor, [Drivers.IBus, Application.get_env(:brain, Drivers.IBus)], [id: Drivers.IBus]),
      worker(Receiver, [Drivers.IBus]),
      worker(@filter, []),

      worker(Neopixel, []),
      worker(PIDController, [[name: Brain.RollRatePIDController]], [id: Brain.RollRatePIDController]),
      worker(PIDController, [[name: Brain.PitchRatePIDController]], [id: Brain.PitchRatePIDController]),
      worker(PIDController, [[name: Brain.YawRatePIDController]], [id: Brain.YawRatePIDController]),
      worker(PIDController, [[name: Brain.PitchAnglePIDController]], [id: Brain.PitchAnglePIDController]),
      worker(PIDController, [[name: Brain.RollAnglePIDController]], [id: Brain.RollAnglePIDController]),

      worker(Interpreter, []),
      worker(Mixer, []),

      worker(BlackBox, []),

      worker(Loop, [])
    ]
    opts = [strategy: :one_for_one, name: Core.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def start_network do
    network_type = Application.get_env(:brain, :network) || :none
    case network_type do
      :ethernet ->
        setup_ethernet()
      :wifi ->
        setup_wifi()
      :both ->
        setup_wifi()
        setup_ethernet()
      :none ->
        Logger.debug("#{__MODULE__} network not configured.")
    end
    Process.sleep(2000) #TODO: improve
    :ok = BlackBox.update_status(:network, network_type)
    advertise_ssdp()
  end

  def production? do
    Application.get_env(:brain, :environment) == :prod
  end

  def init_kernel_modules() do
    Enum.each(@kernel_modules, & System.cmd("modprobe", [&1]))
  end

  defp setup_ethernet do
    case Nerves.Networking.setup(:eth0) do
      {:ok, _pid}                       -> Logger.debug("#{__MODULE__} ethernet started.")
      {:error, {:already_started,_pid}} -> Logger.warn("#{__MODULE__} ethernet already started.")
    end
  end

  defp setup_wifi do
    wifi_configuration = Application.get_env(:brain, :wifi)
    case Nerves.InterimWiFi.setup(:wlan0, ssid: wifi_configuration[:ssid] , key_mgmt: :"WPA-PSK", psk: wifi_configuration[:password]) do
      {:ok, _pid}              -> Logger.debug("#{__MODULE__} wifi started.")
      {:error, :already_added} -> Logger.warn("#{__MODULE__} wifi already started.")
    end
  end

  def advertise_ssdp do
    name = Application.get_env(:brain, :name)
    {:ok, _name} = Nerves.SSDPServer.publish(name, "elicopter",[
      port: Application.get_env(:api, Api.Endpoint)[:http][:port]
    ])
  end
end
