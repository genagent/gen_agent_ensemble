defmodule GenAgentEnsemble.MixProject do
  use Mix.Project

  @version "0.1.0-dev"
  @source_url "https://github.com/genagent/gen_agent_ensemble"

  def project do
    [
      app: :gen_agent_ensemble,
      version: @version,
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      source_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {GenAgentEnsemble.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      gen_agent_dep(),
      {:telemetry, "~> 1.0"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ] ++ backend_deps()
  end

  # Use the sibling path when cloned alongside `gen_agent/` (local
  # monorepo dev), otherwise pull from hex (standalone clone).
  defp gen_agent_dep do
    if File.exists?(Path.expand("../gen_agent/mix.exs", __DIR__)) do
      {:gen_agent, path: "../gen_agent", override: true}
    else
      {:gen_agent, "~> 0.2.0"}
    end
  end

  # Backends are optional in production (this library has no hard
  # dependency on any of them), but we pull them in for dev/test so
  # the config/config.exs example ensembles work out of the box in
  # `iex -S mix`. Path dep when the sibling exists, hex otherwise.
  defp backend_deps do
    for pkg <- ~w(gen_agent_anthropic gen_agent_claude gen_agent_openai gen_agent_codex) do
      sibling = Path.expand("../#{pkg}/mix.exs", __DIR__)
      app = String.to_atom(pkg)

      if File.exists?(sibling) do
        {app, path: "../#{pkg}", only: [:dev, :test]}
      else
        {app, "~> 0.1", only: [:dev, :test]}
      end
    end
  end

  defp description do
    "Multi-agent orchestration strategies for GenAgent. " <>
      "One ensemble process owns N sub-agents under a strategy " <>
      "(Solo, Supervisor, Pool, Pipeline)."
  end

  defp package do
    [
      maintainers: ["Josh Rotenberg"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "GenAgent" => "https://hex.pm/packages/gen_agent"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "guides/workflows/overview.md",
        "guides/workflows/solo.md",
        "guides/workflows/switchboard.md",
        "guides/workflows/pool.md",
        "guides/workflows/pipeline.md",
        "guides/workflows/supervisor.md"
      ],
      groups_for_extras: [
        "Strategy workflows": ~r"guides/workflows/.*"
      ],
      source_ref: "v#{@version}"
    ]
  end
end
