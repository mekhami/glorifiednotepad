defmodule Indie.Stonetop do
  @moduledoc """
  Context for Stonetop TTRPG campaign management.
  """

  import Ecto.Query
  alias Indie.Repo
  alias Indie.Stonetop.{Character, Relationship}

  # --- Characters ---

  @doc "Returns all characters ordered by name"
  def list_characters do
    Repo.all(from(c in Character, order_by: c.name))
  end

  @doc "Returns a character by id"
  def get_character!(id), do: Repo.get!(Character, id)

  @doc "Returns a character by id or nil"
  def get_character(id), do: Repo.get(Character, id)

  @doc "Creates a character"
  def create_character(attrs \\ %{}) do
    %Character{}
    |> Character.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Updates a character"
  def update_character(%Character{} = character, attrs) do
    character
    |> Character.changeset(attrs)
    |> Repo.update()
  end

  @doc "Deletes a character and its relationships"
  def delete_character(%Character{} = character) do
    Repo.delete(character)
  end

  @doc "Returns character with preloaded relationships"
  def get_character_with_relationships(id) do
    Repo.get(Character, id)
    |> maybe_preload_relationships()
  end

  defp maybe_preload_relationships(nil), do: nil

  defp maybe_preload_relationships(character) do
    Repo.preload(character, [:source_relationships, :target_relationships])
  end

  # --- Relationships ---

  @doc "Returns all relationships with source and target preloaded"
  def list_relationships do
    Repo.all(from(r in Relationship, preload: [:source, :target], order_by: r.inserted_at))
  end

  @doc "Returns relationships for a character (both incoming and outgoing)"
  def get_relationships_for_character(character_id) do
    Repo.all(
      from(r in Relationship,
        where: r.source_id == ^character_id or r.target_id == ^character_id,
        preload: [:source, :target],
        order_by: r.inserted_at
      )
    )
  end

  @doc "Creates a relationship between two characters"
  def create_relationship(attrs) do
    %Relationship{}
    |> Relationship.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Updates a relationship"
  def update_relationship(%Relationship{} = relationship, attrs) do
    relationship
    |> Relationship.changeset(attrs)
    |> Repo.update()
  end

  @doc "Deletes a relationship"
  def delete_relationship(%Relationship{} = relationship) do
    Repo.delete(relationship)
  end

  # --- Graph Data for Visualization ---

  @doc "Returns all characters and relationships formatted for the graph canvas"
  def get_graph_data do
    characters = list_characters()
    relationships = list_relationships()

    nodes = Enum.map(characters, &format_node/1)
    edges = Enum.map(relationships, &format_edge/1)

    %{nodes: nodes, edges: edges}
  end

  defp format_node(character) do
    %{
      id: character.id,
      name: character.name,
      description: character.description,
      tags: character.tags,
      image_url: character.image_url
    }
  end

  defp format_edge(relationship) do
    %{
      id: relationship.id,
      source: relationship.source_id,
      target: relationship.target_id,
      description: relationship.description,
      tags: relationship.tags
    }
  end
end
