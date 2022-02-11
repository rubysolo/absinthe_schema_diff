defmodule Absinthe.SchemaDiff.Introspection do
  use TypedStruct

  @query __ENV__.file
         |> Path.dirname()
         |> Path.join("introspection_query.graphql")
         |> File.read!()

  typedstruct module: Schema do
    field :scalars, list(Scalar.t()), default: []
    field :objects, list(Object.t()), default: []
    field :input_objects, list(InputObject.t()), default: []
    field :enums, list(Enumeration.t()), default: []
    field :unions, list(Union.t()), default: []
  end

  typedstruct module: Scalar, enforce: true do
    field :name, String.t()
  end

  typedstruct module: Object, enforce: true do
    field :name, String.t()
    field :fields, list(Field.t())
  end

  typedstruct module: Field, enforce: true do
    field :name, String.t()
    field :deprecated, :boolean
    field :deprecation_reason, String.t()
    field :type, Type.t()
  end

  typedstruct module: Type, enforce: true do
    field :kind, String.t()
    field :name, String.t()
    field :of_type, Type.t()
  end

  typedstruct module: InputObject, enforce: true do
    field :name, String.t()
    field :fields, list(Field.t())
  end

  typedstruct module: Enumeration, enforce: true do
    field :name, String.t()
    field :values, list(Field.t())
  end

  typedstruct module: Union, enforce: true do
    field :name, String.t()
    field :possible_types, list(Type.t())
  end

  # TODO: Diff structure
  # additions, removals, changes (recursive?)

  def generate(schema_module) when is_atom(schema_module) do
    {:ok, %{data: %{"__schema" => raw_schema}}} = Absinthe.run(@query, schema_module)
    build_schema(raw_schema)
  end

  def generate(url) when is_binary(url) do
    {:ok, {_http, _headers, body}} =
      :httpc.request(
        :post,
        {String.to_charlist(url), [{'Content-type', 'application/json'}], '',
         String.to_charlist(@query)},
        [],
        []
      )

    body
    |> to_string()
    |> Jason.decode!()
    |> get_in(["data", "__schema"])
    |> build_schema()
  end

  def build_schema(%{"types" => types}) when is_list(types) do
    Enum.reduce(types, %Schema{}, fn definition, acc ->
      definition
      |> to_schema_type()
      |> insert(acc)
    end)
  end

  defp to_schema_type(%{"kind" => "SCALAR"} = definition) do
    %Scalar{
      name: Map.get(definition, "name")
    }
  end

  defp to_schema_type(%{"kind" => "OBJECT"} = definition) do
    %Object{
      name: Map.get(definition, "name"),
      fields: Map.get(definition, "fields") |> Enum.map(&to_field/1)
    }
  end

  defp to_schema_type(%{"kind" => "INPUT_OBJECT"} = definition) do
    %InputObject{
      name: Map.get(definition, "name"),
      fields: Map.get(definition, "inputFields") |> Enum.map(&to_field/1)
    }
  end

  defp to_schema_type(%{"kind" => "ENUM", "enumValues" => values} = definition) do
    %Enumeration{
      name: Map.get(definition, "name"),
      values: Enum.map(values, &to_field/1)
    }
  end

  defp to_schema_type(%{"kind" => "UNION", "possibleTypes" => types} = definition) do
    %Union{
      name: Map.get(definition, "name"),
      possible_types: Enum.map(types, &to_type/1)
    }
  end

  defp to_field(%{"name" => name} = input) do
    %Field{
      deprecated: Map.get(input, "isDeprecated"),
      deprecation_reason: Map.get(input, "deprecationReason"),
      name: name,
      type: to_type(Map.get(input, "type"))
    }
  end

  defp to_type(nil), do: nil

  defp to_type(%{"kind" => kind, "name" => name, "ofType" => of_type}) do
    %Type{
      kind: kind,
      name: name,
      of_type: to_type(of_type)
    }
  end

  defp insert(%Scalar{} = new, %Schema{scalars: existing} = schema),
    do: %{schema | scalars: [new | existing]}

  defp insert(%Object{} = new, %Schema{objects: existing} = schema),
    do: %{schema | objects: [new | existing]}

  defp insert(%InputObject{} = new, %Schema{input_objects: existing} = schema),
    do: %{schema | input_objects: [new | existing]}

  defp insert(%Enumeration{} = new, %Schema{enums: existing} = schema),
    do: %{schema | enums: [new | existing]}

  defp insert(%Union{} = new, %Schema{unions: existing} = schema),
    do: %{schema | unions: [new | existing]}
end
