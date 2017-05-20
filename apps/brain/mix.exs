defmodule Brain.Mixfile do
  use Mix.Project

  @target System.get_env("MIX_TARGET") || "host"
  Mix.shell.info([:green, """
  Env
    MIX_TARGET:   #{@target}
    MIX_ENV:      #{Mix.env}
  """, :reset])

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
      aliases: aliases(@target),
      deps: deps(@target),
      kernel_modules: kernel_modules(@target, Mix.env)
    ]
  end

  def application do
    [
      mod: {Brain, []},
      applications: applications(@target)
    ]
  end

  def deps("host"), do: base_deps()
  def deps(target) do
    [
      {:"elicopter_system_#{target}", github: "elicopter/elicopter_system_#{target}"},
      {:nerves_runtime, "~> 0.1.0"},
      {:elixir_ale, "0.5.7"},
      {:nerves_interim_wifi, github: "loicvigneron/nerves_interim_wifi", branch: "renew-no-matching-close"},
      {:nerves_neopixel, github: "loicvigneron/nerves_neopixel", branch: "update-deps", submodules: true}
    ] ++ base_deps()
  end

  def base_deps do
    [
      {:api, in_umbrella: true},
      {:drivers, in_umbrella: true},
      {:nerves, "~> 0.5.0", runtime: false},
      {:nerves_uart, "~> 0.1.0"},
      {:nerves_networking, github: "electricshaman/nerves_networking", branch: "cleanup-bare-functions"},
      {:apex, ">= 0.0.0"},
      {:combine, ">= 0.0.0"},
      {:poison, ">= 0.0.0"},
      {:credo, "~> 0.4", only: [:dev, :test]},
      {:nerves_firmware_http, github: "nerves-project/nerves_firmware_http"},
      {:httpoison, "~> 0.11.0"},
      {:nerves_ssdp_server, "~> 0.2.2"},
      {:nerves_ssdp_client, "~> 0.1.3"}
    ]
  end

  def aliases("host"), do: []
  def aliases(_target) do
    [
      "deps.precompile": ["nerves.precompile", "deps.precompile"],
      "deps.loadpaths":  ["deps.loadpaths", "nerves.loadpaths"]
    ]
  end

  defp applications("host"), do: base_applications()

  defp applications(_target) do
    [:nerves_interim_wifi, :elixir_ale, :nerves_neopixel | base_applications()]
  end

  defp base_applications do
    [
      :api,
      :drivers,
      :logger,
      :runtime_tools,
      :nerves_networking,
      :nerves_uart,
      :apex,
      :poison,
      :nerves_firmware_http,
      :nerves_ssdp_server
    ]
  end

  def kernel_modules("rpi3", :prod) do
    ["brcmfmac"]
  end
  def kernel_modules(_, _), do: []
end
