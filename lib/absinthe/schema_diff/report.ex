defmodule Absinthe.SchemaDiff.Report do
  @moduledoc """
  Format a schema diff as console output
  """

  alias Absinthe.SchemaDiff.{
    Diff,
    Diff.DiffSet
  }

  alias Absinthe.SchemaDiff.Introspection.{
    Deprecation,
    Enumeration,
    Field,
    InputObject,
    Object,
    Scalar,
    Type,
    Union
  }

  @nl "\n"
  @tag "[Absinthe.SchemaDiff]" <> @nl

  defmodule Formatter do
    @moduledoc false
    use TypedStruct
    alias __MODULE__

    @indent "  "

    typedstruct do
      field :color, :boolean, default: true
      field :indent, :string, default: ""
    end

    def add_indent(%Formatter{} = formatter, count \\ 1) do
      additional_indent = for _ <- 1..count, do: @indent
      %{formatter | indent: [formatter.indent, additional_indent]}
    end

    def deprecation(%Formatter{color: true}, text), do: magenta(text)
    def deprecation(_, text), do: text

    def inline_type(%Formatter{color: true}, text), do: yellow(text)
    def inline_type(_, text), do: text

    def label(%Formatter{color: true}, text), do: red(text)
    def label(_, text), do: text

    def ok(%Formatter{color: true}, text), do: green(text)
    def ok(_, text), do: text

    def schema_object(%Formatter{color: true}, text), do: cyan(text)
    def schema_object(_, text), do: text

    def type_label(%Formatter{color: true}, text), do: gray(text)
    def type_label(_, text), do: text

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

  def handle(diff_set, opts \\ []) do
    formatter = %Formatter{color: Keyword.get(opts, :color, true)}

    result = [
      tag(),
      report(diff_set, formatter)
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

  def report(diff, formatter \\ %Formatter{})

  def report(%DiffSet{additions: [], removals: [], changes: []}, formatter) do
    [formatter.indent, Formatter.ok(formatter, "no changes."), @nl]
  end

  def report(item, formatter) when is_binary(item) do
    [formatter.indent, item, @nl]
  end

  def report(
        %Diff{
          name: name,
          type: Enumeration,
          changes: %DiffSet{additions: additions, removals: removals}
        },
        formatter
      ) do
    [
      [
        formatter.indent,
        Formatter.type_label(formatter, "Enum"),
        " ",
        Formatter.schema_object(formatter, name),
        @nl
      ],
      report("Additions:", Enum.map(additions, & &1.name), Formatter.add_indent(formatter)),
      report("Removals:", Enum.map(removals, & &1.name), Formatter.add_indent(formatter))
    ]
  end

  def report(
        %Diff{
          name: name,
          type: Field,
          changes: %DiffSet{
            changes: [_ | _] = changes
          }
        },
        formatter
      ) do
    indent_once = Formatter.add_indent(formatter)
    indent_twice = Formatter.add_indent(indent_once)

    Enum.reduce(
      changes,
      [
        [
          formatter.indent,
          Formatter.type_label(formatter, "Field"),
          " ",
          Formatter.schema_object(formatter, name),
          @nl
        ],
        [indent_once.indent, "Changes:", @nl]
      ],
      fn diff, acc ->
        [acc, report(diff, indent_twice)]
      end
    )
  end

  def report(
        %Diff{
          name: name,
          type: Type,
          changes: %DiffSet{
            additions: [new_type],
            removals: [old_type]
          }
        },
        formatter
      ) do
    {name, separator} = if is_nil(name), do: {"", ""}, else: {name, " "}

    [
      formatter.indent,
      Formatter.schema_object(formatter, name),
      separator,
      "type changed from ",
      Formatter.inline_type(formatter, inspect(old_type)),
      " to ",
      Formatter.inline_type(formatter, inspect(new_type)),
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
        formatter
      ) do
    indent_once = Formatter.add_indent(formatter)
    indent_twice = Formatter.add_indent(indent_once)

    Enum.reduce(
      changed_types,
      [
        [
          formatter.indent,
          Formatter.type_label(formatter, "Union"),
          " ",
          Formatter.schema_object(formatter, name),
          @nl
        ],
        [indent_once.indent, "Changes:", @nl]
      ],
      fn diff, acc ->
        [acc, report(diff, indent_twice)]
      end
    )
  end

  def report(%Diff{name: name, type: module, changes: changes}, formatter) do
    label = module_basename(module)

    [
      [
        formatter.indent,
        Formatter.type_label(formatter, label),
        " ",
        Formatter.schema_object(formatter, name),
        @nl
      ],
      report(changes, Formatter.add_indent(formatter))
    ]
  end

  def report(%DiffSet{additions: additions, removals: removals, changes: changes}, formatter) do
    [
      report("Additions:", additions, formatter),
      report("Removals:", removals, formatter),
      report("Changes:", changes, formatter)
    ]
  end

  def report(%Deprecation{reason: reason}, formatter) do
    [
      formatter.indent,
      Formatter.deprecation(formatter, "DEPRECATED - #{reason}"),
      @nl
    ]
  end

  def report(%Enumeration{name: name, values: values}, formatter) do
    indent_once = Formatter.add_indent(formatter)
    indent_twice = Formatter.add_indent(indent_once)

    Enum.reduce(
      values,
      [
        [
          formatter.indent,
          Formatter.type_label(formatter, "Enum"),
          " ",
          Formatter.schema_object(formatter, name),
          @nl
        ],
        [indent_once.indent, "Values:", @nl]
      ],
      fn %{name: name}, acc ->
        [acc, indent_twice.indent, name, @nl]
      end
    )
  end

  def report(%Field{} = field, formatter) do
    deprecation =
      if field.deprecation do
        Formatter.deprecation(formatter, " DEPRECATED - #{field.deprecation.reason}")
      else
        ""
      end

    [
      formatter.indent,
      Formatter.schema_object(formatter, field.name),
      " ",
      Formatter.inline_type(formatter, Diff.render_type(field.type)),
      deprecation,
      @nl
    ]
  end

  def report(%module{name: name, fields: fields}, formatter)
      when module in [InputObject, Object] do
    label = module_basename(module)
    new_formatter = Formatter.add_indent(formatter)

    Enum.reduce(
      fields,
      [
        [
          formatter.indent,
          Formatter.type_label(formatter, label),
          " ",
          Formatter.schema_object(formatter, name),
          @nl
        ],
        [new_formatter.indent, "Fields:", @nl]
      ],
      fn field, acc ->
        [acc, report(field, Formatter.add_indent(new_formatter))]
      end
    )
  end

  def report(%Scalar{name: name}, formatter) do
    [
      formatter.indent,
      Formatter.schema_object(formatter, name),
      " ",
      Formatter.type_label(formatter, "Scalar"),
      @nl
    ]
  end

  def report(%Type{} = type, formatter) do
    [
      formatter.indent,
      Formatter.schema_object(formatter, type.name),
      " ",
      Formatter.inline_type(formatter, Diff.render_type(type)),
      @nl
    ]
  end

  def report(%Union{name: name, possible_types: types}, formatter) do
    indent_once = Formatter.add_indent(formatter)
    indent_twice = Formatter.add_indent(indent_once)

    Enum.reduce(
      types,
      [
        [formatter.indent, "Union #{name}", @nl],
        [indent_once.indent, "Possible Types:", @nl]
      ],
      fn type, acc ->
        [acc, report(type, indent_twice)]
      end
    )
  end

  def report(_label, [], _formatter), do: []

  def report(label, items, formatter) when is_list(items) do
    new_formatter = Formatter.add_indent(formatter)

    items
    |> Enum.sort_by(fn
      %{name: name} -> name
      identity -> identity
    end)
    |> Enum.reduce(
      [formatter.indent, Formatter.label(formatter, label), @nl],
      fn item, acc -> [acc, report(item, new_formatter)] end
    )
  end

  defp module_basename(module) do
    module
    |> to_string()
    |> String.split(".")
    |> List.last()
  end
end
