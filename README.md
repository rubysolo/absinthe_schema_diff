# Absinthe SchemaDiff

Compare the local Absinthe schema with a remote GraphQL schema and report a diff.

## Usage

    mix absinthe.schema.diff [OPTIONS] URL

## Options

* `--schema` - The name of the `Absinthe.Schema` module defining the schema to be compared.
      Default: As [configured](https://hexdocs.pm/mix/Mix.Config.html) for `:absinthe` `:schema`

## Examples

    mix absinthe.schema.diff https://my.server/graphql
