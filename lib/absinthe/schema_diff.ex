defmodule Absinthe.SchemaDiff do
  alias Absinthe.SchemaDiff.Diff
  alias Absinthe.SchemaDiff.Introspection

  @doc """
  compare local Absinthe schema with the GraphQL schema at the provided URL and return a DiffSet
  """
  @spec diff(atom(), String.t()) :: Diff.DiffSet.t()
  def diff(schema, url) do
    local_schema = Introspection.generate(schema)
    remote_schema = Introspection.generate(url)

    Diff.diff(remote_schema, local_schema)
  end
end
