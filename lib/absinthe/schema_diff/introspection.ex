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
    field :interfaces, list(Interface.t()), default: []
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
    field :deprecated, :boolean, default: false
    field :deprecation_reason, String.t(), default: nil
    field :type, Type.t()
  end

  typedstruct module: Type do
    field :kind, String.t(), enforce: true
    field :name, String.t()
    field :of_type, Type.t()
  end

  typedstruct module: InputObject, enforce: true do
    field :name, String.t()
    field :fields, list(Field.t())
  end

  typedstruct module: Interface, enforce: true do
    field :name, String.t()
    field :fields, list(Field.t())
    field :possible_types, list(Type.t())
  end

  typedstruct module: Enumeration, enforce: true do
    field :name, String.t()
    field :values, list(Field.t())
  end

  typedstruct module: Union, enforce: true do
    field :name, String.t()
    field :possible_types, list(Type.t())
  end

  def generate(schema_module) when is_atom(schema_module) do
    {:ok, %{data: %{"__schema" => raw_schema}}} = Absinthe.run(@query, schema_module)
    build_schema(raw_schema)
  end

  def generate("http" <> _ = url) do
    {:ok, {_http, _headers, body}} =
      :httpc.request(
        :post,
        {
          String.to_charlist(url),
          [{'Content-type', 'application/json'}],
          '',
          String.to_charlist(@query)
        },
        Application.get_all_env(:httpc) |> default_httpc_ssl_config(),
        []
      )

    %{"data" => %{"__schema" => raw_schema}} =
      body
      |> to_string()
      |> Jason.decode!()

    build_schema(raw_schema)
  end

  def generate(json) when is_binary(json) do
    %{"data" => %{"__schema" => raw_schema}} = Jason.decode!(json)

    build_schema(raw_schema)
  end

  defp default_httpc_ssl_config(config) do
    case Keyword.get(config, :ssl) do
      nil ->
        Keyword.merge(config, ssl: [
          verify: :verify_peer,
          cacertfile: '/etc/ssl/certs/ca-certificates.crt',
          customize_hostname_check: [
            match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
          ]
        ])

      _ ->
        config
    end
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

  defp to_schema_type(%{"kind" => "INTERFACE", "possibleTypes" => types} = definition) do
    %Interface{
      name: Map.get(definition, "name"),
      fields: Map.get(definition, "fields") |> Enum.map(&to_field/1),
      possible_types: Enum.map(types, &to_type/1)
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

  defp insert(%Interface{} = new, %Schema{interfaces: existing} = schema),
    do: %{schema | interfaces: [new | existing]}

  defp insert(%Enumeration{} = new, %Schema{enums: existing} = schema),
    do: %{schema | enums: [new | existing]}

  defp insert(%Union{} = new, %Schema{unions: existing} = schema),
    do: %{schema | unions: [new | existing]}
end
