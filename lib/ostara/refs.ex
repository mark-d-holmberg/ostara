defmodule Ostara.Refs do
  @moduledoc """
  Post-processes a generated JSON Schema to use `$ref`/`$defs` instead of
  inlining embedded schemas.
  """

  @doc """
  Walks `schema`, extracts any embedded object schemas (those with a `"title"`
  key) into a top-level `"$defs"` block, and replaces their inline occurrences
  with `{"$ref" => "#/$defs/<Title>"}` pointers.
  """
  @spec extract(map()) :: map()
  def extract(schema) do
    {processed, defs} = process_schema(schema, %{})

    if map_size(defs) == 0 do
      processed
    else
      Map.put(processed, "$defs", defs)
    end
  end

  @spec process_schema(map(), map()) :: {map(), map()}
  defp process_schema(schema, defs) do
    case Map.get(schema, "properties") do
      nil ->
        {schema, defs}

      props ->
        {new_props, new_defs} = process_properties(props, defs)
        {Map.put(schema, "properties", new_props), new_defs}
    end
  end

  @spec process_properties(map(), map()) :: {map(), map()}
  defp process_properties(props, defs) do
    Enum.reduce(props, {%{}, defs}, fn {key, val}, {acc, d} ->
      {new_val, new_d} = process_value(val, d)
      {Map.put(acc, key, new_val), new_d}
    end)
  end

  @spec process_value(map(), map()) :: {map(), map()}
  defp process_value(
         %{"type" => "array", "items" => %{"title" => title, "type" => "object"} = items} = prop,
         defs
       ) do
    {processed, new_defs} = process_schema(items, defs)
    new_defs = Map.put(new_defs, title, processed)
    {Map.put(prop, "items", %{"$ref" => "#/$defs/#{title}"}), new_defs}
  end

  defp process_value(%{"title" => title, "type" => "object"} = schema, defs) do
    {processed, new_defs} = process_schema(schema, defs)
    new_defs = Map.put(new_defs, title, processed)
    {%{"$ref" => "#/$defs/#{title}"}, new_defs}
  end

  defp process_value(value, defs), do: {value, defs}
end
