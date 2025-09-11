defmodule Ostara.Schemas.CharacterClass do
  @moduledoc """
  Embedded schema for storing a character's class information.
  """

  use Ecto.Schema
  import Ecto.Changeset
  @derive Jason.Encoder
  @primary_key false

  @type t :: %__MODULE__{
          class_key: binary(),
          subclass_key: binary() | nil,
          ability_proficiency: binary() | nil,
          save_proficiency: binary() | nil,
          proficiency_bonus: binary() | nil,
          level: integer() | nil
        }

  @attrs [
    :class_key,
    :subclass_key,
    :level,
    :ability_proficiency,
    :save_proficiency,
    :proficiency_bonus
  ]

  @required_attrs [:class_key, :level]

  embedded_schema do
    field(:class_key, :string)
    field(:subclass_key, :string)
    field(:ability_proficiency, :string)
    field(:save_proficiency, :string)
    field(:proficiency_bonus, :string)
    field(:level, :integer)
  end

  @spec new(map() | list()) :: t()
  def new(params) when is_map(params) do
    params
    |> changeset(%__MODULE__{})
    |> apply_action!(:insert)
  end

  def new(params) when is_list(params) do
    params
    |> Map.new()
    |> new()
  end

  @spec changeset(map(), t()) :: Ecto.Changeset.t()
  def changeset(attrs, feature \\ %__MODULE__{}) do
    feature
    |> cast(attrs, @attrs)
    |> validate_required(@required_attrs)
    |> update_change(:class_key, &String.trim/1)
    |> update_change(:subclass_key, &String.trim/1)
    |> update_change(:ability_proficiency, &String.trim/1)
    |> update_change(:save_proficiency, &String.trim/1)
    |> update_change(:proficiency_bonus, &String.trim/1)
  end
end
