defmodule Ostara.Properties do
  @moduledoc """
  Functions for converting `Ecto.Schema` fields to JSON Schema properties.
  """

  alias Ostara.JSONSchema

  @doc """
  Puts a `"properties"` key in the given `map` based on the fields defined
  in the `source`.

  `source` should be an `Ecto.Schema` module.
  """
  @spec put_properties(map(), atom()) :: map()
  def put_properties(map, source) do
    properties = get_properties(source)
    Map.put(map, "properties", properties)
  end

  @spec get_properties(atom()) :: map()
  defp get_properties(source) do
    data = struct(source)

    source
    |> get_fields()
    |> Map.new(fn field ->
      name = JSONSchema.field_name(field)
      type = propertize_type(source.__schema__(:type, field))

      type =
        case {field, Map.get(data, field)} do
          {:type, v} when is_binary(v) and v != "" ->
            Map.put(type, "const", v)

          _ ->
            type
        end

      {name, type}
    end)
  end

  @spec get_fields(atom()) :: map()
  defp get_fields(source) do
    source.__schema__(:fields)
  end

  @spec propertize_type({:parameterized, {struct(), map()}}) :: map()
  # Ecto.Enum with values → "enum"
  defp propertize_type({:parameterized, {Ecto.Enum, params}}) do
    values =
      cond do
        is_map(params) and Map.has_key?(params, :mappings) ->
          if Keyword.keyword?(params.mappings) do
            params.mappings
            |> Map.new()
            |> Map.keys()
          else
            Map.keys(params.mappings)
          end

        is_map(params) and Map.has_key?(params, :values) and is_list(params.values) ->
          params.values

        true ->
          nil
      end

    case values do
      nil -> %{"type" => "string"}
      list when is_list(list) -> %{"type" => "string", "enum" => Enum.map(list, &to_string/1)}
    end
  end

  defp propertize_type({:parameterized, {Ecto.Embedded, %{related: source, cardinality: :one}}}) do
    JSONSchema.generate(source)
  end

  defp propertize_type({:parameterized, {Ecto.Embedded, %{related: source, cardinality: :many}}}) do
    %{
      "type" => "array",
      "items" => JSONSchema.generate(source)
    }
  end

  @spec propertize_type(atom() | {:parameterized, struct(), map()}) :: map()
  defp propertize_type(:binary_id) do
    %{"type" => "string"}
  end

  # Back-compat for the alternate tuple form some Ecto versions emit
  defp propertize_type({:parameterized, Ecto.Enum, params}) do
    propertize_type({:parameterized, {Ecto.Enum, params}})
  end

  defp propertize_type(:naive_datetime), do: %{"type" => "string", "format" => "date-time"}
  defp propertize_type(:utc_datetime), do: %{"type" => "string", "format" => "date-time"}
  defp propertize_type(:utc_datetime_usec), do: %{"type" => "string", "format" => "date-time"}
  defp propertize_type(:date), do: %{"type" => "string", "format" => "date"}
  defp propertize_type(:time), do: %{"type" => "string", "format" => "time"}

  # Allow any value
  defp propertize_type(:any), do: %{}

  # Arrays of any
  defp propertize_type({:array, :any}) do
    %{"type" => "array", "items" => %{}}
  end

  defp propertize_type(:float) do
    %{"type" => "number"}
  end

  defp propertize_type(:map), do: %{"type" => "object"}

  defp propertize_type({:array, type}) do
    type =
      type
      |> propertize_type()
      |> Map.fetch!("type")

    %{
      "type" => "array",
      "items" => %{
        "type" => type
      }
    }
  end

  defp propertize_type({:parameterized, Ecto.Embedded, %{related: source, cardinality: :one}}) do
    JSONSchema.generate(source)
  end

  defp propertize_type({:parameterized, Ecto.Embedded, %{related: source, cardinality: :many}}) do
    %{
      "type" => "array",
      "items" => JSONSchema.generate(source)
    }
  end

  defp propertize_type(type) do
    %{"type" => to_string(type)}
  end
end
