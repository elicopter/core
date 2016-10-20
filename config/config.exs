use Mix.Config

config :nerves, :firmware,
  rootfs_additions: "config/rootfs-additions"
config :nerves_interim_wifi,
  regulatory_domain: "US"

config :core, :wifi_configuration,
  ssid: "elicopter",
  psk: "elicopter2016",
  interface: "wlan0",
  key_mgmt: :"WPA-PSK"

config :core, :barometer, Sensor.BMP180
config :core, :magnetometer, Sensor.LSM303DLHCMagnetometer
config :core, :accelerometer, Sensor.LSM303DLHCAccelerometer
config :core, :gyroscope, Sensor.L3GD20H

config :core, :filter, Filter.Complementary

config :core, :sample_rate, 30

import_config "#{Mix.env}.exs"
