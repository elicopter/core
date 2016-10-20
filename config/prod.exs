use Mix.Config

config :core, :i2c, I2c
config :core, :i2c_device_name, "i2c-1"
config :core, :motor_pwm, Driver.PCA9685
config :core, :receiver, Receiver.Ibus
config :core, :uart, Nerves.UART
config :core, :wifi, Nerves.InterimWiFi
config :core, :black_box_rabbitmq,
  url: "amqp://core:core@192.168.142.100",
  exchange: "black_box_events"
config :core, :commander_rabbitmq,
  url: "amqp://core:core@192.168.142.100",
  exchange: "commands"
