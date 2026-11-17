defmodule Ostara.Filter do
  @moduledoc """
  Restricts the top-level `"properties"` and `"required"` of a generated JSON
  Schema to a whitelist (`:only`) and/or removes a blacklist (`:except`).
  """

  @doc """
  Applies `only` then `except` to `schema`. Either may be `nil` (no-op).

  Raises `ArgumentError` if a name in `only` is not a property of the schema,
  so typos in a whitelist fail loudly instead of silently dropping a field.
  """
  @spec apply(map(), [atom() | String.t()] | nil, [atom() | String.t()] | nil) :: map()
  def apply(schema, nil, nil), do: schema

  def apply(%{"properties" => props} = schema, only, except) do
    only = only && names(only)
    except = names(except || [])

    if only do
      unknown = Enum.reject(only, &Map.has_key?(props, &1))

      if unknown != [] do
        raise ArgumentError,
              "Ostara :only lists unknown fields #{inspect(unknown)} " <>
                "(available: #{inspect(Map.keys(props))})"
      end
    end

    keep? = fn name ->
      (is_nil(only) or name in only) and name not in except
    end

    schema
    |> Map.put("properties", Map.filter(props, fn {name, _} -> keep?.(name) end))
    |> Map.update("required", [], &Enum.filter(&1, keep?))
  end

  def apply(schema, _only, _except), do: schema

  defp names(list), do: Enum.map(list, &to_string/1)
end
