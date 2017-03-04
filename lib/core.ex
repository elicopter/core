defmodule Core do
  use Application
  require Logger

  @receiver        Application.get_env(:core, :receiver)
  @motor_pwm       Application.get_env(:core, :motor_pwm)
  @i2c             Application.get_env(:core, :i2c)
  @i2c_device_name Application.get_env(:core, :i2c_device_name)
  @uart            Application.get_env(:core, :uart)
  @accelerometer   Application.get_env(:core, :accelerometer)
  @magnetometer    Application.get_env(:core, :magnetometer)
  @gyroscope       Application.get_env(:core, :gyroscope)
  @barometer       Application.get_env(:core, :barometer)
  @filter          Application.get_env(:core, :filter)

  def start(_type, _args) do
    # if production? do
    #   {:ok, _} = Nerves.NetworkInterface.status("wlan0")
    #   Logger.debug "Check if wlan0 is up, reboot if not."
    # end
    import Supervisor.Spec
    children = [
      worker(@i2c, [@i2c_device_name, 0, [name: :barometer_i2c]], [id: :barometer_i2c]),
      worker(@barometer, [:barometer_i2c, :barometer]),

      worker(@i2c, [@i2c_device_name, 0, [name: :gyroscope_i2c]], [id: :gyroscope_i2c]),
      worker(@gyroscope, [:gyroscope_i2c, :gyroscope]),

      worker(@i2c, [@i2c_device_name, 0, [name: :accelerometer_i2c]], [id: :accelerometer_i2c]),
      worker(@accelerometer, [:accelerometer_i2c, :accelerometer]),

      worker(@i2c, [@i2c_device_name, 0, [name: :magnetometer_i2c]], [id: :magnetometer_i2c]),
      worker(@magnetometer, [:magnetometer_i2c, :magnetometer]),

      worker(@uart, [[name: :receiver_uart]], [id: :receiver_uart]),
      worker(@receiver, [:receiver_uart, "ttyS0", :receiver]),

      worker(@i2c, [@i2c_device_name, 0, [name: :motor_pwm_i2c]], [id: :motor_pwm_i2c]),
      worker(@motor_pwm, [:motor_pwm_i2c, :motor_pwm]),

      worker(@filter, [:filter]),

      worker(PIDController, [:roll_rate_pid_controller], [id: :roll_rate_pid_controller]),
      worker(PIDController, [:pitch_rate_pid_controller], [id: :pitch_rate_pid_controller]),
      worker(PIDController, [:yaw_rate_pid_controller], [id: :yaw_rate_pid_controller]),
      worker(PIDController, [:pitch_angle_pid_controller], [id: :pitch_angle_pid_controller]),
      worker(PIDController, [:roll_angle_pid_controller], [id: :roll_angle_pid_controller]),

      worker(Interpreter, []),
      worker(Mixer, []),
      worker(Motors, [:motor_pwm]),

      worker(BlackBox, [:black_box]),
      worker(Commander, [:commander]),

      worker(Brain, [])
    ]
    opts = [strategy: :one_for_one, name: Core.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def production? do
    System.get_env("CORE_ENV") == "prod" || System.get_env("CORE_ENV") == :prod
  end
end
