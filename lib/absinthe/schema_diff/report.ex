defmodule Absinthe.SchemaDiff.Report do
  @moduledoc """
  Generate console output to report a schema diff
  """

  alias Absinthe.SchemaDiff.{
    Diff,
    Diff.DiffSet
  }

  alias Absinthe.SchemaDiff.Introspection.{
    Enumeration,
    Field,
    Type
  }

  @tag "[Absinthe.SchemaDiff]\n"
  @indent "  "

  def tag do
    IO.puts(@tag)
  end

  def report(diff, indent \\ "")

  def report(%DiffSet{additions: [], removals: [], changes: []}, _indent) do
    IO.puts(green("no changes."))
  end

  def report(item, indent) when is_binary(item) do
    IO.puts(indent <> item)
  end

  def report(
        %Diff{
          name: name,
          type: Enumeration,
          changes: %DiffSet{additions: additions, removals: removals}
        },
        indent
      ) do
    IO.puts(indent <> gray("Enum") <> " " <> cyan(name) <> ":")

    report("Additions:", Enum.map(additions, & &1.name), indent)
    report("Removals:", Enum.map(removals, & &1.name), indent)
  end

  def report(%Diff{name: name, type: Field, changes: %DiffSet{changes: changes}}, indent) do
    IO.puts(indent <> gray("Field") <> " " <> cyan(name) <> ":")
    Enum.each(changes, fn c -> report(c, indent <> @indent) end)
  end

  def report(
        %Diff{type: Type, changes: %DiffSet{additions: [new_type], removals: [old_type]}},
        indent
      ) do
    IO.puts(indent <> "type changed from " <> yellow(old_type) <> " to " <> yellow(new_type))
  end

  def report(
        %Diff{
          name: name,
          type: nil,
          changes: %DiffSet{additions: [new_value], removals: [old_value]}
        },
        indent
      ) do
    IO.puts(
      indent <>
        cyan(name) <>
        " changed from " <> yellow(inspect(old_value)) <> " to " <> yellow(inspect(new_value))
    )
  end

  def report(%Diff{name: name, type: module, changes: changes}, indent) do
    label =
      module
      |> to_string()
      |> String.split(".")
      |> List.last()

    IO.puts(indent <> gray(label) <> " " <> cyan(name) <> ":")
    report(changes, indent)
  end

  def report(%DiffSet{additions: additions, removals: removals, changes: changes}, indent) do
    report("Additions:", additions, indent)
    report("Removals:", removals, indent)
    report("Changes:", changes, indent)
  end

  def report(%Field{} = field, indent) do
    deprecation =
      if field.deprecated do
        magenta(" DEPRECATED - #{field.deprecation_reason}")
      else
        ""
      end

    IO.puts(indent <> "Field #{field.name} (#{Diff.render_type(field.type)})" <> deprecation)
  end

  def report(_label, [], _indent), do: :ok

  def report(label, items, indent) when is_list(items) do
    IO.puts(indent <> red(label))
    Enum.each(items, fn item -> report(item, indent <> @indent) end)
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

  # blue
  # magenta
  # yellow

  # + light_ variants

  # faint
  # bright
end
