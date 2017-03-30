use Mix.Config

config :brain, :network, :none

config :brain, :storage,
  root_path: "./tmp"

config :brain, :loop,
  sleep: 8

config :brain, Brain.BlackBox,
  root_path: "./tmp/black_box"