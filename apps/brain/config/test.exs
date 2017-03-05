use Mix.Config

config :brain, :i2c, Dummy.I2c
config :brain, :i2c_device_name, "i2c-1"
config :brain, :motor_pwm, Driver.PCA9685
config :brain, :receiver, Dummy.Ibus
config :brain, :uart, Dummy.UART
config :brain, :wifi, Dummy.Wifi
config :brain, :black_box_rabbitmq,
  url: "amqp://brain:brain@localhost",
  exchange: "black_box_events"
config :brain, :commander_rabbitmq,
  url: "amqp://brain:brain@localhost",
  exchange: "commands"
