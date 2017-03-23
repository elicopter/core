defmodule Brain do
  use Application
  require Logger
  alias Brain.BlackBox

  @filter Application.get_env(:brain, :filter)
  @kernel_modules Mix.Project.config[:kernel_modules] || []

  def start(_type, _args) do
    import Supervisor.Spec
    children = [
      worker(Task, [fn -> init_kernel_modules() end], restart: :transient, id: Nerves.Init.KernelModules),
      worker(Task, [fn -> start_network() end], restart: :transient, id: Brain.Network),
      supervisor(Brain.Sensors.Supervisor, []),
      supervisor(Brain.Actuators.Supervisor, []),
      supervisor(Drivers.Supervisor, [Drivers.IBus, Application.get_env(:brain, Drivers.IBus)], [id: Drivers.IBus]),
      worker(Brain.Receiver, [Drivers.IBus]),
      worker(@filter, []),

      worker(Brain.Neopixel, []),
      worker(Brain.PIDController, [[name: Brain.RollRatePIDController]], [id: Brain.RollRatePIDController]),
      worker(Brain.PIDController, [[name: Brain.PitchRatePIDController]], [id: Brain.PitchRatePIDController]),
      worker(Brain.PIDController, [[name: Brain.YawRatePIDController]], [id: Brain.YawRatePIDController]),
      worker(Brain.PIDController, [[name: Brain.PitchAnglePIDController]], [id: Brain.PitchAnglePIDController]),
      worker(Brain.PIDController, [[name: Brain.RollAnglePIDController]], [id: Brain.RollAnglePIDController]),

      worker(Brain.Interpreter, []),
      worker(Brain.Mixer, []),

      worker(Brain.BlackBox, []),
      # worker(Commander, [:commander]),

      worker(Brain.Loop, [])
    ]
    opts = [strategy: :one_for_one, name: Core.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def start_network do
    if production?() do
      network_type = Application.get_env(:brain, :network)
      case network_type do
        :ethernet ->
          setup_ethernet()
        :wifi ->
          setup_wifi()
        :both ->
          setup_wifi()
          setup_ethernet()

      end
      :ok = BlackBox.update_status(:network, network_type)
    end
    Process.sleep(2000) #TODO: improve
    advertise_ssdp()
  end

  def production? do
    Application.get_env(:brain, :environment) == :prod
  end

  def init_kernel_modules() do
    Enum.each(@kernel_modules, & System.cmd("modprobe", [&1]))
  end

  defp setup_ethernet do
    {:ok, _pid} = Nerves.Networking.setup(:eth0)
  end

  defp setup_wifi do
    wifi_configuration = Application.get_env(:brain, :wifi)
    {:ok, _pid} = Nerves.InterimWiFi.setup(:wlan0, ssid: wifi_configuration[:ssid] , key_mgmt: :"WPA-PSK", psk: wifi_configuration[:password])
  end

  def advertise_ssdp do
    name = Application.get_env(:brain, :name)
    Nerves.SSDPServer.publish(name, "elicopter",[
      port: Application.get_env(:api, Api.Endpoint)[:http][:port]
    ])
  end
end
