defmodule Ostara.Validation do
  @moduledoc """
  Converts `Ecto.Changeset` validators into JSON Schema validations
  by inspecting changesets at runtime (no AST parsing).

  Guarantees (aligned with existing tests/behavior):
    * snake_case field names
    * inline embedded schemas
    * open objects (no additionalProperties here)
    * number/length/format validations mapped
    * required fields from `changeset.required` (incl. required embeds)
  """

  alias Ostara.JSONSchema
  require Logger

  @doc """
  Annotates the `"properties"` in `map` based on the runtime `changeset/2`
  of `module`.

  Notes:
    * We call the schema's `changeset/2` defensively via `build_changeset/1`
      to tolerate different arities/usages and schemas that call `apply_action!/2`.
    * Populates root `"required"` from `cs.required`.
    * Maps:
        - `:number`  -> minimum/maximum, exclusiveMinimum/exclusiveMaximum
        - `:length`  -> minLength/maxLength for strings; minItems/maxItems for arrays
        - `:format`  -> pattern (regex)
  """
  @spec put_validations(map(), atom()) :: map()
  def put_validations(%{"properties" => _} = map, module) when is_atom(module) do
    cs = build_changeset(module)

    # 1) Required fields (validate_required & cast_embed(..., required: true))
    required = cs.required |> Enum.map(&JSONSchema.field_name/1)
    map = update_required(map, required)

    # 2) Known validations
    Enum.reduce(cs.validations, map, fn {field, {validator, opts}}, acc ->
      json_field = JSONSchema.field_name(field)

      case validator do
        :number ->
          validations =
            Enum.reduce(opts, %{}, fn
              {:less_than, v}, acc -> Map.put(acc, "exclusiveMaximum", v)
              {:greater_than, v}, acc -> Map.put(acc, "exclusiveMinimum", v)
              {:less_than_or_equal_to, v}, acc -> Map.put(acc, "maximum", v)
              {:greater_than_or_equal_to, v}, acc -> Map.put(acc, "minimum", v)
              _, acc -> acc
            end)

          update_property(acc, json_field, validations)

        :length ->
          ecto_type = module.__schema__(:type, field)

          {min_key, max_key} =
            case ecto_type do
              {:array, _} -> {"minItems", "maxItems"}
              _ -> {"minLength", "maxLength"}
            end

          validations =
            Enum.reduce(opts, %{}, fn
              {:min, v}, acc -> Map.put(acc, min_key, v)
              {:max, v}, acc -> Map.put(acc, max_key, v)
              {:is, v}, acc -> acc |> Map.put(min_key, v) |> Map.put(max_key, v)
              _, acc -> acc
            end)

          update_property(acc, json_field, validations)

        :format ->
          # Ecto stores as {regex, opts}; be tolerant of older shapes too.
          {regex, _} =
            case opts do
              {r, o} -> {r, o}
              r -> {r, []}
            end

          update_property(acc, json_field, %{"pattern" => Regex.source(regex)})

        _other ->
          acc
      end
    end)
  end

  # If "properties" key is missing, return map unchanged
  def put_validations(map, _module), do: map

  # ----------------------------------------------------------------------------
  # Internal helpers
  # ----------------------------------------------------------------------------

  # Build a changeset defensively:
  # 1) try (data, %{})
  # 2) try (%{}, data)
  # 3) try (data, dummy_params)
  # 4) try (dummy_params, data)

  # Try calling changeset with params-first first, then with embed seeds, then data-first.
  defp build_changeset(module) do
    data = struct(module)
    empty = %{}
    seeds = embed_seed_params(module) |> Map.merge(dummy_params(module))

    # 1) params-first, empty
    try do
      module.changeset(empty, data)
    rescue
      _ ->
        # 2) params-first, with seeds (embeds + dummy scalars)
        try do
          module.changeset(seeds, data)
        rescue
          _ ->
            # 3) data-first, empty
            try do
              module.changeset(data, empty)
            rescue
              _ ->
                # 4) data-first, with seeds
                module.changeset(data, seeds)
            end
        end
    end
  end

  # Build seed params for embeds so cast_embed sees a map (or list) – never a struct.
  defp embed_seed_params(module) do
    Enum.reduce(module.__schema__(:embeds), %{}, fn field, acc ->
      %{cardinality: cardinality} = module.__schema__(:embed, field)

      value =
        case cardinality do
          # embeds_one expects a map
          :one -> %{}
          # embeds_many expects a list of maps
          :many -> []
        end

      Map.put(acc, Atom.to_string(field), value)
    end)
  end

  # Seed scalar fields so validate_required won’t raise, and cast/validate have something to chew on.
  defp dummy_params(module) do
    Enum.reduce(module.__schema__(:fields), %{}, fn field, acc ->
      type = module.__schema__(:type, field)
      Map.put(acc, Atom.to_string(field), dummy_value(type))
    end)
  end

  # ------------------ dummy values (unchanged except final default is non-blank) ------------------

  defp dummy_value({:array, _inner}), do: []
  defp dummy_value({:parameterized, {Ecto.Embedded, _}}), do: %{}
  defp dummy_value(:map), do: %{}
  defp dummy_value(:integer), do: 0
  defp dummy_value(:float), do: 0.0
  defp dummy_value(:boolean), do: false
  defp dummy_value(:binary_id), do: "00000000-0000-0000-0000-000000000000"
  # non-empty placeholder
  defp dummy_value(:binary), do: "AA=="
  defp dummy_value(:date), do: "1970-01-01"
  defp dummy_value(:time), do: "00:00:00"
  defp dummy_value(:naive_datetime), do: "1970-01-01T00:00:00"
  defp dummy_value(:utc_datetime), do: "1970-01-01T00:00:00Z"
  defp dummy_value(:utc_datetime_usec), do: "1970-01-01T00:00:00Z"

  # Ecto.Enum first valid value if present
  defp dummy_value({:parameterized, {Ecto.Enum, params}}) do
    val =
      cond do
        is_map(params) and Map.has_key?(params, :mappings) ->
          params.mappings |> Map.keys() |> List.first()

        is_map(params) and Map.has_key?(params, :values) and is_list(params.values) ->
          List.first(params.values)

        true ->
          "value"
      end

    to_string(val || "value")
  end

  defp dummy_value({:parameterized, Ecto.Enum, params}),
    do: dummy_value({:parameterized, {Ecto.Enum, params}})

  # Default to non-blank string so validate_required passes
  defp dummy_value(_), do: "x"

  @spec update_required(map(), [String.t()]) :: map()
  defp update_required(map, list) do
    required =
      map
      |> Map.get("required", [])
      |> Kernel.++(list)
      |> Enum.uniq()
      |> Enum.sort()

    Map.put(map, "required", required)
  end

  @spec update_property(map(), String.t(), map()) :: map()
  defp update_property(map, field, update) do
    updated =
      map
      |> Map.fetch!("properties")
      |> Map.fetch!(field)
      |> Map.merge(update)

    put_in(map, ["properties", field], updated)
  end
end
