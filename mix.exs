defmodule WebResearcher.MixProject do
  use Mix.Project

  def project do
    [
      app: :web_researcher,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {WebResearcher.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:req, "~> 0.5.8"},
      {:html2markdown, "~> 0.1.5"},
      {:playwright, "~> 1.49.1-alpha.1"},
      {:ecto, "~> 3.12.5"}
    ]
  end
end
