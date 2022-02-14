defmodule Mix.Tasks.Absinthe.Schema.Diff do
  use Mix.Task

  require Logger

  alias Absinthe.SchemaDiff
  alias Absinthe.SchemaDiff.Diff

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
    use TypedStruct

    typedstruct enforce: true do
      field :handlers, list(String.t())
      field :schema, String.t()
      field :url, String.t()
    end
  end

  @impl Mix.Task
  def run(argv) do
    Application.ensure_all_started(:absinthe)

    Mix.Task.run("loadpaths", argv)
    Mix.Task.run("compile", argv)

    opts = parse_options(argv)

    opts
    |> run_diff()
    |> handle_diff(opts)
  end

  def run_diff(%Options{schema: schema, url: url}) do
    SchemaDiff.diff(schema, url)
  end

  def handle_diff(diff_set, %Options{handlers: handlers}) do
    Enum.each(handlers, & &1.handle(diff_set))
    System.stop(if Diff.empty?(diff_set), do: 0, else: 1)
  end

  def parse_options(argv) do
    {opts, args, _} =
      OptionParser.parse(argv, strict: [handler: :keep, quiet: :boolean, schema: :string])

    opts = accumulate_keyword(opts)

    %Options{
      handlers: find_handlers(opts),
      schema: find_schema(opts),
      url: validate_url(args),
    }
  end

  defp accumulate_keyword(list) when is_list(list) do
    list
    |> Enum.reduce([], fn {k, v}, acc ->
      case Keyword.get(acc, k) do
        nil ->
          Keyword.put(acc, k, v)
        existing when is_list(existing) ->
          Keyword.put(acc, k, [v | existing])
        existing ->
          Keyword.put(acc, k, [v, existing])
      end
    end)
    |> Enum.map(fn
      {k, v} when is_list(v) -> {k, Enum.reverse(v)}
      kv -> kv
    end)
  end

  defp default_handlers(opts) do
    if Keyword.get(opts, :quiet, false) do
      []
    else
      [Absinthe.SchemaDiff.Report]
    end
  end

  defp find_handlers(opts) do
    requested_handlers =
      case Keyword.get(opts, :handler, []) do
        handlers when is_list(handlers) -> handlers
        handler -> [handler]
      end

    opts
    |> default_handlers()
    |> Enum.concat(requested_handlers)
    |> Enum.uniq()
    |> Enum.map(&validate_handler_module/1)
    |> Enum.filter(& &1)
  end

  defp validate_handler_module(module) when is_atom(module), do: module
  defp validate_handler_module(module_name) do
    result =
      [module_name]
      |> Module.concat()
      |> Code.ensure_compiled()

    case result do
      {:module, module} ->
        module
      {:error, _} ->
        Logger.warn "Could not find handler module #{module_name}"
        nil
    end
  end

  defp find_schema(opts) do
    case Keyword.get(opts, :schema, Application.get_env(:absinthe, :schema)) do
      nil ->
        raise "No --schema given or :schema configured for the :absinthe application"

      value ->
        [value] |> Module.safe_concat()
    end
  end

  defp validate_url(["http" <> _ = url | _]), do: url
  defp validate_url(_), do: raise("No URL given for remote GraphQL API")
end
