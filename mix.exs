defmodule AbsintheSchemaDiff.MixProject do
  use Mix.Project

  def project do
    [
      app: :absinthe_schema_diff,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:inets, :logger]
    ]
  end

  defp deps do
    [
      {:absinthe, ">= 0.0.0"},
      {:jason, ">= 0.0.0"},
      {:typed_struct, ">= 0.0.0"}
    ]
  end
end
