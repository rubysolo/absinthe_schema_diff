defmodule Mix.Tasks.Absinthe.Schema.Diff do
  use Mix.Task

  alias Absinthe.SchemaDiff
  alias Absinthe.SchemaDiff.Diff.DiffSet
  alias Absinthe.SchemaDiff.Report

  @shortdoc "Compare a local Absinthe schema with a remote GrahpQL schema"

  @moduledoc """
  Compare the local Absinthe schema with a remote GraphQL schema and report a diff.

  ## Usage

      mix absinthe.schema.diff [OPTIONS] URL

  ## Options

  * `--schema` - The name of the `Absinthe.Schema` module defining the schema to be compared.
       Default: As [configured](https://hexdocs.pm/mix/Mix.Config.html) for `:absinthe` `:schema`

  ## Examples

      mix absinthe.schema.diff https://my.server/graphql
  """

  defmodule Options do
    @moduledoc false
    defstruct url: nil, schema: nil

    @type t() :: %__MODULE__{
            url: String.t(),
            schema: module()
          }
  end

  @impl Mix.Task
  def run(argv) do
    Application.ensure_all_started(:absinthe)

    Mix.Task.run("loadpaths", argv)
    Mix.Task.run("compile", argv)

    opts = parse_options(argv)

    case run_diff(opts) do
      {:error, error} -> raise error
      diff -> handle_diff(diff)
    end
  end

  def run_diff(%Options{schema: schema, url: url}) do
    SchemaDiff.diff(schema, url)
  end

  def handle_diff(diff_set) do
    Report.tag()
    Report.report(diff_set)
    :ok
  end

  def parse_options(argv) do
    {opts, args, _} = OptionParser.parse(argv, strict: [schema: :string])

    %Options{
      url: validate_url(args),
      schema: find_schema(opts)
    }
  end

  defp validate_url(["http" <> _ = url | _]), do: url

  defp validate_url([url | _]) when is_binary(url) do
    IO.puts("warning: '#{url}' does not look like a url")
    url
  end

  defp validate_url(_), do: raise("No URL given for remote GraphQL API")

  defp find_schema(opts) do
    case Keyword.get(opts, :schema, Application.get_env(:absinthe, :schema)) do
      nil ->
        raise "No --schema given or :schema configured for the :absinthe application"

      value ->
        [value] |> Module.safe_concat()
    end
  end
end
