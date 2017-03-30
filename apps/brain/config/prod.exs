use Mix.Config

config :brain, :storage,
  root_path: "/root"

config :brain, :loop,
  sleep: 0

config :brain, Brain.BlackBox,
  root_path: "/mnt/black_box"