defmodule Ostara do
  @moduledoc """
  `Ostara` transforms [Ecto](https://hexdocs.pm/ecto/Ecto.html) schema
  modules into [JSON Schema](https://json-schema.org/) structures.

  ## Example

  Given the following schema module:

      defmodule Product do
        @moduledoc "A product from Acme's catalog",
        use Ecto.Schema

        @primary_key false

        embedded_schema do
         field :product_name, :string
         field :price, :float
        end

        def changeset(data, params) do
         data
         |> cast(params, [:product_name, :price])
         |> validate_required([:product_name])
         |> validate_number(:price, greater_than: 0)
        end
      end

  `transmute/1` will produce the following map:

      %{
        "$schema" => "https://json-schema.org/draft/2020-12/schema",
        "title" => "Product",
        "type" => "object",
        "description" => "A product from Acme's catalog",
        "properties" => %{
          "productName" => %{
            "type" => "string"
          },
          "price" => %{
            "type" => "number",
            "exclusiveMinimum" => 0
          }
        },
        "required" => ["productName"]
      }
  """

  alias __MODULE__.{Filter, JSONSchema, Refs}

  @doc """
  Produces a JSON Schema based on the given `source` module.

  ## Options

    * `:format` - If `:json`, returns the data as pretty-printed JSON
    * `:refs` - If `true`, extracts embedded schemas into a top-level `"$defs"`
      block and replaces inline occurrences with `{"$ref" => "#/$defs/<Title>"}`
      pointers instead of inlining them
    * `:only` - A whitelist of top-level field names (atoms or strings). Every
      other property is removed from `"properties"` and `"required"`. Because
      filtering happens before `:refs` extraction, embedded schemas that are
      excluded never appear in `"$defs"`
    * `:except` - A blacklist of top-level field names. Applied after `:only`

  """
  @spec transmute(atom(), keyword()) :: map() | String.t()
  def transmute(source, opts \\ []) when is_atom(source) do
    format = Keyword.get(opts, :format)
    refs = Keyword.get(opts, :refs, false)

    schema =
      source
      |> JSONSchema.generate(root: true)
      |> Filter.apply(Keyword.get(opts, :only), Keyword.get(opts, :except))

    schema = if refs, do: Refs.extract(schema), else: schema

    if format == :json do
      Jason.encode!(schema, pretty: true)
    else
      schema
    end
  end
end
