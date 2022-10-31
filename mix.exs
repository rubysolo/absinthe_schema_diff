defmodule AbsintheSchemaDiff.MixProject do
  use Mix.Project

  def project do
    [
      app: :absinthe_schema_diff,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Absinthe SchemaDiff",
      source_url: "https://github.com/rubysolo/absinthe_schema_diff",
      docs: [
        extras: ["README.md"]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:inets, :logger, :ssl]
    ]
  end

  defp deps do
    [
      {:absinthe, "~> 1.7.0"},
      {:ex_doc, "~> 0.27", only: :dev, runtime: false},
      {:jason, "~> 1.3"},
      {:typed_struct, "~> 0.2"}
    ]
  end
end
