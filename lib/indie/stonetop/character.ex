defmodule Indie.Stonetop.Character do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "characters" do
    field(:name, :string)
    field(:description, :string)
    field(:tags, {:array, :string}, default: [])
    field(:image_url, :string)

    field(:tags_input, :string, virtual: true)

    has_many(:source_relationships, Indie.Stonetop.Relationship,
      foreign_key: :source_id,
      on_delete: :delete_all
    )

    has_many(:target_relationships, Indie.Stonetop.Relationship,
      foreign_key: :target_id,
      on_delete: :delete_all
    )

    timestamps()
  end

  @doc false
  def changeset(character, attrs) do
    attrs = normalize_tags(attrs)

    character
    |> cast(attrs, [:name, :description, :tags, :image_url])
    |> validate_required([:name])
    |> validate_length(:name, max: 100)
    |> validate_length(:description, max: 5000)
  end

  defp normalize_tags(attrs) do
    cond do
      attrs["tags_input"] -> Map.put(attrs, "tags", parse_tags(attrs["tags_input"]))
      is_binary(attrs["tags"]) -> Map.put(attrs, "tags", parse_tags(attrs["tags"]))
      true -> attrs
    end
  end

  defp parse_tags(tags_string) do
    tags_string
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end
end
