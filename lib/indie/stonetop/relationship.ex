defmodule Indie.Stonetop.Relationship do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "relationships" do
    belongs_to(:source, Indie.Stonetop.Character, foreign_key: :source_id)
    belongs_to(:target, Indie.Stonetop.Character, foreign_key: :target_id)
    field(:description, :string)
    field(:tags, {:array, :string}, default: [])

    timestamps()
  end

  @doc false
  def changeset(relationship, attrs) do
    attrs = normalize_tags(attrs)

    relationship
    |> cast(attrs, [:source_id, :target_id, :description, :tags])
    |> validate_required([:source_id, :target_id])
    |> validate_length(:description, max: 5000)
    |> unique_constraint(:source_id, name: :relationships_source_id_target_id_index)
  end

  defp normalize_tags(attrs) do
    case attrs["tags"] do
      tags when is_binary(tags) ->
        Map.put(attrs, "tags", parse_tags(tags))

      tags when is_list(tags) ->
        attrs

      _ ->
        Map.put(attrs, "tags", [])
    end
  end

  defp parse_tags(tags_string) do
    tags_string
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end
end
