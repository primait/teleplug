defmodule Teleplug.MixProject do
  use Mix.Project

  @source_url "https://github.com/primait/teleplug"
  @version "2.0.0"

  def project do
    [
      app: :teleplug,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      aliases: aliases(),
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    []
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:opentelemetry_api, "~> 1.1"},
      {:opentelemetry_semantic_conventions, "~> 1.27"},
      {:plug, "~> 1.11"},
      {:telemetry, "~> 0.4 or ~> 1.0"}
    ] ++ dev_deps()
  end

  def dev_deps do
    [
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.1", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:opentelemetry, "~> 1.0", only: :test},
      {:opentelemetry_exporter, "~> 1.0", only: :test}
    ]
  end

  def package do
    [
      description: "Teleplug is a dead simple opentelemetry-instrumented plug.",
      name: "teleplug",
      maintainer: ["prima.it"],
      licenses: ["MIT"],
      links: %{"Github" => "https://github.com/primait/teleplug"}
    ]
  end

  defp aliases do
    [
      "format.all": [
        "format mix.exs \"lib/**/*.{ex,exs}\" \"test/**/*.{ex,exs}\" \"priv/**/*.{ex,exs}\" \"config/**/*.{ex,exs}\""
      ]
    ]
  end

  defp docs do
    [
      extras: [
        "CHANGELOG.md": [title: "Changelog"],
        "LICENSE.md": [title: "License"],
        "README.md": [title: "Overview"]
      ],
      main: "readme",
      source_url: @source_url,
      source_ref: @version,
      formatters: ["html"]
    ]
  end
end
