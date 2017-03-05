use Mix.Config

config :brain, :i2c, I2c
config :brain, :i2c_device_name, "i2c-1"
config :brain, :motor_pwm, Driver.PCA9685
# config :brain, :receiver, Receiver.Ibus
config :brain, :receiver, Dummy.Ibus
config :brain, :uart, Dummy.UART

# config :brain, :uart, Nerves.UART
config :brain, :wifi, Nerves.InterimWiFi
