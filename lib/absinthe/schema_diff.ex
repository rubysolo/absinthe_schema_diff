defmodule Absinthe.SchemaDiff do
  alias Absinthe.SchemaDiff.Diff
  alias Absinthe.SchemaDiff.Introspection

  @doc """
  Compare local Absinthe schema with the GraphQL schema from the provided source and return a DiffSet
  """
  @spec diff(atom(), String.t()) :: Diff.DiffSet.t()
  def diff(schema, source) do
    local_schema = Introspection.generate(schema)
    base_schema = Introspection.generate(source)

    Diff.diff(base_schema, local_schema)
  end
end
