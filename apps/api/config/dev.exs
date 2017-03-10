use Mix.Config

config :api, Api.Endpoint,
  http: [port: 4000],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [],
  server: true

config :api, Api.Endpoint,
  live_reload: [
    patterns: [
      ~r{web/.*(ex)$}
    ]
  ]

config :phoenix, :stacktrace_depth, 20
