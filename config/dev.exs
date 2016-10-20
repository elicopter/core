use Mix.Config

config :core, :i2c, Dummy.I2c
config :core, :i2c_device_name, "i2c-1"
config :core, :motor_pwm, Driver.PCA9685
config :core, :receiver, Dummy.Ibus
config :core, :uart, Dummy.UART
config :core, :wifi, Dummy.Wifi
config :core, :black_box_rabbitmq,
  url: "amqp://core:core@localhost",
  exchange: "black_box_events"
config :core, :commander_rabbitmq,
  url: "amqp://core:core@localhost",
  exchange: "commands"
