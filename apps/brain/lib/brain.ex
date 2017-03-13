defmodule Brain do
  use Application
  require Logger

  @filter Application.get_env(:brain, :filter)

  def start(_type, _args) do
    # if production? do
    #   {:ok, _} = Nerves.NetworkInterface.status("wlan0")
    #   Logger.debug "Check if wlan0 is up, reboot if not."
    # end
    import Supervisor.Spec
    children = [
      worker(Task, [fn -> start_network end], restart: :transient),
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
      case Application.get_env(:brain, :network) do
        :ethernet ->
          {:ok, _pid} = Nerves.Networking.setup(:eth0)
        :wifi ->
          wifi_configuration = Application.get_env(:brain, :wifi)
          IO.inspect Nerves.InterimWiFi.setup("wlan0", ssid: wifi_configuration[:ssid] , key_mgmt: :"WPA-PSK", psk: wifi_configuration[:password])
      end
    end
  end

  def production? do
    Application.get_env(:brain, :environment) == :prod
  end
end
