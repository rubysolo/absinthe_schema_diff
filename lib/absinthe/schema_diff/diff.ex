defmodule Absinthe.SchemaDiff.Diff do
  use TypedStruct

  # TODO: enum value as: <-- changed "as"
  # TODO: changes to mutation field args

  alias Absinthe.SchemaDiff.Diff

  alias Absinthe.SchemaDiff.Introspection.{
    Enumeration,
    Field,
    InputObject,
    Object,
    Schema,
    Type,
    Union
  }

  typedstruct module: DiffSet do
    field :additions, list(struct()), default: []
    field :removals, list(struct()), default: []
    field :changes, list(DiffSet.t()), default: []
  end

  typedstruct do
    field :type, atom()
    field :name, String.t()
    field :changes, DiffSet.t()
  end

  def empty?(%DiffSet{} = diff_set) do
    %DiffSet{} == diff_set
  end

  def diff(match, match) do
    %DiffSet{}
  end

  def diff({atom, existing}, {atom, new}) when is_atom(atom) do
    %DiffSet{
      changes: [
        %Diff{
          name: to_string(atom),
          changes: %DiffSet{
            additions: [new],
            removals: [existing]
          }
        }
      ]
    }
  end

  def diff(existing, new) when is_binary(existing) and is_binary(new) do
    %DiffSet{
      additions: [new],
      removals: [existing]
    }
  end

  def diff(%Enumeration{} = existing, %Enumeration{} = new) do
    %DiffSet{
      changes: [
        %Diff{type: Enumeration, name: existing.name, changes: diff(existing.values, new.values)}
      ]
    }
  end

  def diff(%Field{} = existing, %Field{} = new) do
    %DiffSet{
      changes: [
        %Diff{
          type: Field,
          name: existing.name,
          changes:
            reduce_diffs([
              {{:deprecated, existing.deprecated}, {:deprecated, new.deprecated}},
              {{:deprecation_reason, existing.deprecation_reason},
               {:deprecation_reason, new.deprecation_reason}},
              {existing.type, new.type}
            ])
        }
      ]
    }
  end

  def diff(%module{} = existing, %module{} = new) when module in [InputObject, Object] do
    %DiffSet{
      changes: [
        %Diff{type: module, name: existing.name, changes: diff(existing.fields, new.fields)}
      ]
    }
  end

  def diff(%Type{} = existing, %Type{} = new) do
    %DiffSet{
      changes: [
        %Diff{
          type: Type,
          name: existing.name,
          changes: diff(render_type(existing), render_type(new))
        }
      ]
    }
  end

  def diff(%Union{} = existing, %Union{} = new) do
    %DiffSet{
      changes: [
        %Diff{
          type: Union,
          name: existing.name,
          changes: diff(existing.possible_types, new.possible_types)
        }
      ]
    }
  end

  def diff(%Schema{} = existing, %Schema{} = new) do
    existing
    |> Map.from_struct()
    |> Enum.map(fn {key, values} -> {values, Map.get(new, key)} end)
    |> reduce_diffs()
  end

  def diff(existing, new) when is_list(existing) and is_list(new) do
    existing_index = Enum.reduce(existing, %{}, &insert_by_name/2)
    new_index = Enum.reduce(new, %{}, &insert_by_name/2)

    existing_names = Map.keys(existing_index)
    new_names = Map.keys(new_index)

    existing_names
    |> Enum.concat(new_names)
    |> Enum.uniq()
    |> Enum.map(&{Map.get(existing_index, &1), Map.get(new_index, &1)})
    |> reduce_diffs()
  end

  defp reduce_diffs(diffs) when is_list(diffs) do
    Enum.reduce(diffs, %DiffSet{}, fn
      {nil, new_item}, %{additions: additions} = acc ->
        %{acc | additions: [new_item | additions]}

      {existing_item, nil}, %{removals: removals} = acc ->
        %{acc | removals: [existing_item | removals]}

      {existing_item, new_item}, %{} = acc ->
        case diff(existing_item, new_item) do
          [] ->
            acc

          %{} = diff ->
            %DiffSet{
              additions: Enum.concat(diff.additions, acc.additions),
              removals: Enum.concat(diff.removals, acc.removals),
              changes: Enum.concat(diff.changes, acc.changes)
            }
        end
    end)
  end

  defp insert_by_name(%{name: name} = struct, map) do
    Map.put(map, name, struct)
  end

  def render_type(%Type{kind: "SCALAR", name: name, of_type: nil}), do: name
  def render_type(%Type{kind: kind, of_type: nil}), do: String.downcase(kind)

  def render_type(%Type{kind: kind, of_type: of_type}) do
    "#{String.downcase(kind)}(#{render_type(of_type)})"
  end
end
