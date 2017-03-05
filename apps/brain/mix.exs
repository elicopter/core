defmodule Brain.Mixfile do
  use Mix.Project

  @target System.get_env("NERVES_TARGET") || "rpi3"

  def project do
    [
      app: :brain,
      version: "0.1.0",
      target: @target,
      archives: [nerves_bootstrap: "~> 0.2.1"],
      deps_path: "../../deps/#{@target}",
      build_path: "../../_build/#{@target}",
      config_path: "../../config/config.exs",
      lockfile: "../../mix.lock",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      aliases: aliases(),
      deps: deps() ++ system(@target)
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Brain, []},
      applications: [
        :runtime_tools,
        :nerves,
        :nerves_networking,
        :nerves_interim_wifi,
        :nerves_uart,
        :logger,
        :apex,
        :poison,
        :elixir_ale,
        :api,
        :drivers
      ]
    ]
  end

  def deps do
    [
      {:api, in_umbrella: true},
      {:drivers, in_umbrella: true},
      {:nerves, "~> 0.4.0"},
      {:nerves_uart, git: "https://github.com/nerves-project/nerves_uart.git"},
      {:nerves_interim_wifi, "~> 0.1.0"},
      {:nerves_networking, github: "nerves-project/nerves_networking"},
      {:elixir_ale, "0.5.7"},
      {:apex, ">= 0.0.0"},
      {:combine, ">= 0.0.0"},
      {:poison, ">= 0.0.0"},
      {:credo, "~> 0.4", only: [:dev, :test]},
    ]
  end

  def system(target) do
    [{:"nerves_system_#{target}", ">= 0.0.0"}]
  end

  def aliases do
    [
      "deps.precompile": ["nerves.precompile", "deps.precompile"],
      "deps.loadpaths":  ["deps.loadpaths", "nerves.loadpaths"]
    ]
  end

end
