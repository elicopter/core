use Mix.Config

config :nerves, :firmware,
  rootfs_additions: "config/rootfs-additions"
config :nerves_interim_wifi,
  regulatory_domain: "US"

config :brain, :wifi_configuration,
  ssid: "elicopter",
  psk: "elicopter2016",
  interface: "wlan0",
  key_mgmt: :"WPA-PSK"

config :brain, :filter, Filter.Complementary

config :brain, :sample_rate, 30

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
  address: 0x6B

config :brain, Drivers.IBus,
  bus: :uart,
  bus_name: "ttyUSB0"

import_config "#{Mix.env}.exs"
