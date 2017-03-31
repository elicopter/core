use Mix.Config

config :nerves, :firmware,
  rootfs_additions: "config/rootfs-additions",
  fwup_conf: "config/rpi3/fwup.conf"

config :nerves_interim_wifi,
  regulatory_domain: "US"

config :logger,
  backends: [Brain.ChannelLoggerBackend, :console],
  level: :debug

config :brain, :name, "My Elicopter"
config :brain, :environment, Mix.env

config :brain, :wifi,
  ssid: System.get_env("ELICOPTER_WIFI_SSID"),
  password: System.get_env("ELICOPTER_WIFI_PASSWORD")

config :brain, :network, :both

config :brain, Brain.BlackBox,
  loops_buffer_limit: 100,
  send_loop_interval: 100

config :brain, Brain.Neopixel,
  channel0: [pin: 18, count: 8]

config :brain, :filter, Brain.Filter.Complementary

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

config :brain, Brain.RollRatePIDController,
  kp: 0.7,
  ki: 0,
  kd: 0,
  minimum_output: -500,
  maximum_output: 500

config :brain, Brain.PitchRatePIDController,
  kp: 0.7,
  ki: 0,
  kd: 0,
  minimum_output: -500,
  maximum_output: 500

config :brain, Brain.YawRatePIDController,
  kp: 1.7,
  ki: 0,
  kd: 0,
  minimum_output: -500,
  maximum_output: 500

config :brain, Brain.RollAnglePIDController,
  kp: 1.5,
  ki: 0,
  kd: 0,
  minimum_output: -400,
  maximum_output: 400

config :brain, Brain.PitchAnglePIDController,
  kp: -1.5,
  ki: 0,
  kd: 0,
  minimum_output: -400,
  maximum_output: 400

import_config "#{Mix.env}.exs"
