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

  def application do
    [
      mod: {Brain, []},
      applications: applications(Mix.env)
    ]
  end

  def deps do
    [
      {:api, in_umbrella: true},
      {:drivers, in_umbrella: true},
      {:nerves, "~> 0.4.0"},
      {:nerves_uart, git: "https://github.com/nerves-project/nerves_uart.git"},
      {:nerves_interim_wifi, "~> 0.1.0", only: [:prod]},
      {:nerves_networking, github: "nerves-project/nerves_networking"},
      {:elixir_ale, "0.5.7", only: [:prod]},
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

  defp applications(:prod) do
    [:nerves_interim_wifi, :elixir_ale | base_applications()]
  end

  defp applications(_) do
    base_applications()
  end

  defp base_applications do
    [
      :runtime_tools,
      :nerves,
      :nerves_networking,
      :nerves_uart,
      :logger,
      :apex,
      :poison,
      :api,
      :drivers
    ]
  end
end
