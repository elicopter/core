# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# Configures the endpoint
config :api, Api.Endpoint,
  http: [port: 80],
  url: [host: "elicopter"],
  server: true,
  secret_key_base: "yaneuLYOLLf+ugGPDGz5ABk0wmgV+LNt7jabFR/qUnkBRMFxt33KpMESScGl8UGw",
  render_errors: [view: Api.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Api.PubSub,
           adapter: Phoenix.PubSub.PG2]

import_config "#{Mix.env}.exs"
