defmodule Ostara.Schemas.Sheet do
  @moduledoc """
  A Character Sheet that we can save.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Ostara.Schemas.CharacterClass

  @primary_key false
  @derive Jason.Encoder

  @type t :: %__MODULE__{
          player_name: binary(),
          name: binary(),
          race_key: binary(),
          class_key: binary(),
          gender: binary(),
          alignment: binary(),
          background_key: binary(),
          sheet_id: binary(),
          revision: integer(),
          created_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t(),
          transforms: list(),
          tags: list(),
          type: binary(),
          character_class: CharacterClass.t() | nil
        }

  @attrs [
    :player_name,
    :name,
    :race_key,
    :class_key,
    :gender,
    :alignment,
    :background_key,
    :sheet_id,
    :revision,
    :created_at,
    :updated_at,
    :tags,
    :transforms
  ]

  @required_attrs [
    :sheet_id
  ]

  embedded_schema do
    field(:player_name, :string)
    field(:name, :string)
    field(:race_key, :string)
    field(:class_key, :string)
    field(:gender, :string)
    field(:alignment, :string)
    field(:background_key, :string)
    field(:sheet_id, :string, default: Ecto.UUID.generate())
    field(:revision, :integer)
    field(:created_at, :naive_datetime, default: nil)
    field(:updated_at, :naive_datetime, default: nil)
    field(:transforms, {:array, :any}, default: [])
    field(:tags, {:array, :string}, default: [])
    field(:type, :string, default: "sheet")

    embeds_one(:character_class, CharacterClass, on_replace: :update)
  end

  @doc """
  Make a new Sheet struct
  """
  def new() do
    new(%{
      sheet_id: Ecto.UUID.generate(),
      created_at: now(),
      updated_at: now()
    })
  end

  @spec new(map()) :: t()
  def new(params) when is_map(params) do
    %__MODULE__{}
    |> changeset(params)
    |> apply_action!(:insert)
  end

  def new(params) when is_list(params) do
    params
    |> Map.new()
    |> new()
  end

  defp now() do
    NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
  end

  defp maybe_set_created_at(changeset) do
    case get_field(changeset, :created_at, nil) do
      nil ->
        put_change(changeset, :created_at, now())

      _other ->
        changeset
    end
  end

  defp maybe_set_updated_at(changeset) do
    case get_field(changeset, :updated_at, nil) do
      nil ->
        put_change(changeset, :updated_at, now())

      _other ->
        changeset
    end
  end

  defp maybe_increment_revision(%Ecto.Changeset{changes: %{revision: revision}} = changeset)
       when is_integer(revision) do
    put_change(changeset, :revision, revision + 1)
  end

  defp maybe_increment_revision(changeset) do
    changeset
  end

  defp maybe_set_revision_if_nil(%Ecto.Changeset{changes: %{revision: revision}} = changeset)
       when not is_nil(revision) do
    changeset
  end

  defp maybe_set_revision_if_nil(%Ecto.Changeset{changes: changes} = changeset)
       when is_map(changes) do
    put_change(changeset, :revision, 1)
  end

  # TODO: we want to use changeset to set transforms maybe?

  @spec changeset(map(), t()) :: Ecto.Changeset.t()
  def changeset(module \\ %__MODULE__{}, attrs) do
    module
    |> cast(attrs, @attrs)
    |> cast_embed(:character_class)
    |> validate_required(@required_attrs)
    |> maybe_set_created_at()
    |> maybe_set_updated_at()
    |> maybe_increment_revision()
    |> maybe_set_revision_if_nil()
    |> update_change(:player_name, &String.trim/1)
    |> update_change(:name, &String.trim/1)
    |> update_change(:race_key, &String.trim/1)
    |> update_change(:class_key, &String.trim/1)
    |> update_change(:gender, &String.trim/1)
    |> update_change(:alignment, &String.trim/1)
    |> update_change(:background_key, &String.trim/1)
    |> update_change(:sheet_id, &String.trim/1)
    |> validate_length(:player_name, min: 1, max: 40)
    |> validate_length(:name, min: 1, max: 20)
  end
end
