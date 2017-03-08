use Mix.Config

config :drivers, Drivers.BMP180,
  configuration: :bmp180

config :drivers, Drivers.L3GD20H,
  configuration: :l3gd20h

config :drivers, Drivers.PCA9685,
  configuration: :pca9685

config :drivers, Drivers.LSM303DLHCMagnetometer,
  configuration: :lsm303dlhc_magnetometer

config :drivers, Drivers.LSM303DLHCAccelerometer,
  configuration: :lsm303dlhc_accelerometer

import_config "#{Mix.env}.exs"
