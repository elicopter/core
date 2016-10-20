defmodule Core.Mixfile do
  use Mix.Project

  @target System.get_env("NERVES_TARGET") || "rpi3"

  def project do
    [app: :core,
     version: "0.0.1",
     target: @target,
     archives: [nerves_bootstrap: "~> 0.1.4"],
     deps_path: "deps/#{@target}",
     build_path: "_build/#{@target}",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     aliases: aliases,
     deps: deps ++ system(@target)]
  end

  def application do
    [
      mod: {Core, []},
      applications: [
        :nerves,
        :nerves_interim_wifi,
        :nerves_uart,
        :logger,
        :apex,
        :amqp,
        :poison
      ]
    ]
  end

  def deps do
    [
      {:nerves, "~> 0.3"},
      {:nerves_uart, git: "https://github.com/nerves-project/nerves_uart.git"},
      {:nerves_interim_wifi, "~> 0.1.0"},
      {:elixir_ale, "~> 0.5.5"},
      {:apex, ">= 0.0.0"},
      {:combine, ">= 0.0.0"},
      {:amqp, github: "loicvigneron/amqp"},
      {:poison, ">= 0.0.0"},
      {:credo, "~> 0.4", only: [:dev, :test]},
      {:mock, "~> 0.1.1", only: :test}
    ]
  end

  def system(target) do
    [{:"nerves_system_#{target}", ">= 0.0.0"}]
  end

  def aliases do
    ["deps.precompile": ["nerves.precompile", "deps.precompile"],
     "deps.loadpaths":  ["deps.loadpaths", "nerves.loadpaths"]]
  end

end
