defmodule Brain.Mixfile do
  use Mix.Project

  @target System.get_env("NERVES_TARGET") || "rpi3"

  def project do
    [
      app: :brain,
      version: "0.1.0",
      target: @target,
      archives: [nerves_bootstrap: "~> 0.3.1"],
      deps_path: "../../deps/#{@target}",
      build_path: "../../_build/#{@target}",
      config_path: "../../config/config.exs",
      lockfile: "../../mix.lock",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      aliases: aliases(),
      deps: deps() ++ system(@target),
      kernel_modules: kernel_modules(@target, Mix.env)
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
      {:nerves, "~> 0.5.0"},
      {:nerves_uart, git: "https://github.com/nerves-project/nerves_uart.git"},
      {:nerves_interim_wifi, "~> 0.1.0"},
      {:nerves_networking, github: "nerves-project/nerves_networking"},
      {:elixir_ale, "0.5.7", only: [:prod]},
      {:apex, ">= 0.0.0"},
      {:combine, ">= 0.0.0"},
      {:poison, ">= 0.0.0"},
      {:credo, "~> 0.4", only: [:dev, :test]},
      {:nerves_firmware_http, github: "nerves-project/nerves_firmware_http"},
      {:httpoison, "~> 0.11.0"},
      {:nerves_neopixel, github: "loicvigneron/nerves_neopixel", branch: "update-deps", submodules: true},
      {:nerves_ssdp_server, "~> 0.2.2"},
      {:nerves_ssdp_client, "~> 0.1.3"},
      {:timex, "> 0.0.0"}
    ]
  end

  def system(target) do
    [{:"elicopter_system_#{target}", github: "elicopter/elicopter_system_#{target}"}]
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
      :timex,
      :api,
      :logger,
      :runtime_tools,
      :nerves,
      :nerves_networking,
      :nerves_uart,
      :apex,
      :poison,
      :drivers,
      :nerves_firmware_http,
      :nerves_neopixel,
      :nerves_ssdp_server
    ]
  end

  def kernel_modules("rpi3", :prod) do
    ["brcmfmac"]
  end
  def kernel_modules(_, _), do: []
end
