defmodule Absinthe.SchemaDiff.Report do
  @moduledoc """
  Format a schema diff as console output
  """

  alias Absinthe.SchemaDiff.{
    Diff,
    Diff.DiffSet
  }

  alias Absinthe.SchemaDiff.Introspection.{
    Enumeration,
    Field,
    InputObject,
    Object,
    Type,
    Union
  }

  @nl "\n"
  @tag "[Absinthe.SchemaDiff]" <> @nl
  @indent "  "

  def handle(diff_set, opts \\ []) do
    result = [
      tag(),
      report(diff_set)
    ]

    case Keyword.get(opts, :output, :stdout) do
      :stdout -> IO.puts(result)
      :string -> Enum.join(result)
      other -> raise "unknown output option #{inspect(other)}"
    end
  end

  def tag do
    [@tag]
  end

  def report(diff, indent \\ "")

  def report(%DiffSet{additions: [], removals: [], changes: []}, _indent) do
    [green("no changes."), @nl]
  end

  def report(item, indent) when is_binary(item) do
    [indent, item, @nl]
  end

  def report(
        %Diff{
          name: name,
          type: Enumeration,
          changes: %DiffSet{additions: additions, removals: removals}
        },
        indent
      ) do
    [
      [indent, gray("Enum"), " ", cyan(name), @nl],
      report("Additions:", Enum.map(additions, & &1.name), [indent, @indent]),
      report("Removals:", Enum.map(removals, & &1.name), [indent, @indent])
    ]
  end

  def report(
        %Diff{
          name: name,
          type: Field,
          changes: %DiffSet{
            changes: [
              %Diff{
                type: Type,
                changes: %DiffSet{
                  additions: [new_type],
                  removals: [old_type]
                }
              }
            ]
          }
        },
        indent
      ) do
    [
      indent,
      cyan(name),
      " type changed from ",
      yellow(old_type),
      " to ",
      yellow(new_type),
      @nl
    ]
  end

  def report(
        %Diff{
          name: name,
          type: _type,
          changes: %DiffSet{additions: [new_value], removals: [old_value]}
        },
        indent
      ) do
    [
      indent,
      cyan(name),
      " changed from ",
      yellow(inspect(old_value)),
      " to ",
      yellow(inspect(new_value)),
      @nl
    ]
  end

  def report(
        %Diff{
          name: name,
          type: Union,
          changes: %DiffSet{
            changes: [_ | _] = changed_types
          }
        },
        indent
      ) do
    Enum.reduce(
      changed_types,
      [
        [indent, gray("Union"), " ", cyan(name), @nl],
        [[indent, @indent], "Changes:", @nl],
      ],
      fn diff, acc ->
        [acc, report(diff, [indent, @indent, @indent])]
      end
    )
  end

  def report(%Diff{name: name, type: module, changes: changes}, indent) do
    label = module_basename(module)

    [
      [indent, gray(label), " ", cyan(name), @nl],
      report(changes, [indent, @indent])
    ]
  end

  def report(%DiffSet{additions: additions, removals: removals, changes: changes}, indent) do
    [
      report("Additions:", additions, indent),
      report("Removals:", removals, indent),
      report("Changes:", changes, indent)
    ]
  end

  def report(%Enumeration{name: name, values: values}, indent) do
    Enum.reduce(
      values,
      [
        [indent, gray("Enum"), " ", cyan(name), @nl],
        [indent, @indent, "Values:", @nl]
      ],

      fn %{name: name}, acc ->
        [acc, indent, @indent, @indent, name, @nl]
      end
    )
  end

  def report(%Field{} = field, indent) do
    deprecation =
      if field.deprecated do
        magenta(" DEPRECATED - #{field.deprecation_reason}")
      else
        ""
      end

    [
      indent,
      cyan(field.name),
      " ",
      yellow(Diff.render_type(field.type)),
      deprecation,
      @nl
    ]
  end

  def report(%module{name: name, fields: fields}, indent) when module in [InputObject, Object] do
    label = module_basename(module)

    Enum.reduce(
      fields,
      [
        [indent, gray(label), " ", cyan(name), @nl],
        [indent, @indent, "Fields:", @nl]
      ],
      fn field, acc ->
        [acc, report(field, [indent, @indent, @indent])]
      end
    )
  end

  def report(%Type{} = type, indent) do
    [indent, cyan(type.name), " ", yellow(Diff.render_type(type)), @nl]
  end

  def report(%Union{name: name, possible_types: types}, indent) do
    Enum.reduce(
      types,
      [
        [indent, "Union #{name}", @nl],
        [indent, @indent, "Possible Types:", @nl]
      ],
      fn type, acc ->
        [acc, report(type, [indent, @indent, @indent])]
      end
    )
  end

  def report(_label, [], _indent), do: []

  def report(label, items, indent) when is_list(items) do
    Enum.reduce(
      items,
      [indent, red(label), @nl],
      fn item, acc -> [acc, report(item, [indent, @indent])] end
    )
  end

  defp module_basename(module) do
    module
    |> to_string()
    |> String.split(".")
    |> List.last()
  end

  defp cyan(text) do
    IO.ANSI.cyan() <> text <> IO.ANSI.reset()
  end

  defp gray(text) do
    IO.ANSI.light_black() <> text <> IO.ANSI.reset()
  end

  defp green(text) do
    IO.ANSI.green() <> text <> IO.ANSI.reset()
  end

  defp magenta(text) do
    IO.ANSI.magenta() <> text <> IO.ANSI.reset()
  end

  defp red(text) do
    IO.ANSI.red() <> text <> IO.ANSI.reset()
  end

  defp yellow(text) do
    IO.ANSI.yellow() <> text <> IO.ANSI.reset()
  end
end
