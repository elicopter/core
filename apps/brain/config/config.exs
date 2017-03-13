use Mix.Config

config :nerves, :firmware,
  rootfs_additions: "config/rootfs-additions"

config :nerves_interim_wifi,
  regulatory_domain: "US"

config :brain, :environment, Mix.env

config :brain, :wifi,
  ssid: System.get_env("ELICOPTER_WIFI_SSID"),
  password: System.get_env("ELICOPTER_WIFI_PASSWORD")

config :brain, :network, :both

config :brain, Brain.BlackBox,
  buffer_limit: 30

config :brain, Brain.Neopixel,
  channel0: [pin: 18, count: 8]

config :brain, :firmware_http,
  url: "http://elicopter:8988"

config :brain, :wifi_configuration,
  ssid: "elicopter",
  psk: "elicopter2016",
  interface: "wlan0",
  key_mgmt: :"WPA-PSK"

config :brain, :filter, Filter.Complementary

config :brain, :sample_rate, 15

config :brain, :sensors, [
  # Brain.Sensors.Barometer, # Need to be fixed
  Brain.Sensors.Magnetometer,
  Brain.Sensors.Accelerometer,
  Brain.Sensors.Gyroscope
]

config :brain, Brain.Sensors.Gyroscope,
  driver: Drivers.L3GD20H

config :brain, Brain.Sensors.Accelerometer,
  driver: Drivers.LSM303DLHCAccelerometer

config :brain, Brain.Sensors.Magnetometer,
  driver: Drivers.LSM303DLHCMagnetometer

config :brain, Brain.Sensors.Barometer,
  driver: Drivers.BMP180

config :brain, :actuators, [
  Brain.Actuators.Motors
]

config :brain, Brain.Actuators.Motors,
  driver: Drivers.PCA9685

config :brain, Drivers.PCA9685,
  bus: :i2c,
  bus_name: "i2c-1",
  address: 0x40

config :brain, Drivers.BMP180,
  bus: :i2c,
  bus_name: "i2c-1",
  address: 0x77

config :brain, Drivers.LSM303DLHCAccelerometer,
  bus: :i2c,
  bus_name: "i2c-1",
  address: 0x19

config :brain, Drivers.LSM303DLHCMagnetometer,
  bus: :i2c,
  bus_name: "i2c-1",
  address: 0x1E

config :brain, Drivers.L3GD20H,
  bus: :i2c,
  bus_name: "i2c-1",
  address: 0x6B,
  zero_rate_x_drift: 0,
  zero_rate_y_drift: 0,
  zero_rate_z_drift: 0

config :brain, Drivers.IBus,
  bus: :uart,
  bus_name: "ttyUSB0"

import_config "#{Mix.env}.exs"
