use Mix.Config

config :brain, Brain.Memory,
  root_path: "/root"

config :brain, :loop,
  sleep: 0

config :brain, Brain.BlackBox,
  root_path: "/mnt/black_box"

config :nerves_interim_wifi, :logger,
  level: :warn