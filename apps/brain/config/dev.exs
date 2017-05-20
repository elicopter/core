use Mix.Config

config :brain, :network, :none

config :brain, Brain.Memory,
  root_path: "./tmp"

config :brain, :loop,
  sleep: 8

config :brain, Brain.BlackBox,
  root_path: "./tmp/black_box"

config :brain, :neopixel, Brain.Dummy.Neopixel
config :brain, :interim_wifi, Brain.Dummy.InterimWifi
