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
      extra_applications: [:inets, :logger, :ssl]
    ]
  end

  defp deps do
    [
      {:absinthe, "~> 1.7.0"},
      {:jason, "~> 1.3.0"},
      {:typed_struct, "~> 0.2.1"}
    ]
  end
end
