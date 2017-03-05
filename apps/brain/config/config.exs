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

config :brain, :barometer, Sensor.BMP180
config :brain, :magnetometer, Sensor.LSM303DLHCMagnetometer
config :brain, :accelerometer, Sensor.LSM303DLHCAccelerometer
config :brain, :gyroscope, Sensor.L3GD20H

config :brain, :filter, Filter.Complementary

config :brain, :sample_rate, 30


config :drivers, :pca9685,
  bus_name: "i2c-1",
  address: 0x40
import_config "#{Mix.env}.exs"
