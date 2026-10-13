defmodule Indie.Stonetop do
  @moduledoc """
  Context for Stonetop TTRPG campaign management.
  """

  import Ecto.Query
  alias Indie.Repo
  alias Indie.Stonetop.{Character, Relationship, ParentChild, Partnership}

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

  # --- Family: parent/child links ---

  @doc "Creates a parent/child link, rejecting links that would form a cycle"
  def create_parent_child(attrs) do
    changeset = ParentChild.changeset(%ParentChild{}, attrs)
    parent_id = Ecto.Changeset.get_field(changeset, :parent_id)
    child_id = Ecto.Changeset.get_field(changeset, :child_id)

    if changeset.valid? and creates_cycle?(parent_id, child_id) do
      {:error,
       changeset
       |> Ecto.Changeset.add_error(:child_id, "would make someone their own ancestor")
       |> Map.put(:action, :insert)}
    else
      Repo.insert(changeset)
    end
  end

  @doc "Updates a parent/child link (kind only)"
  def update_parent_child(%ParentChild{} = link, attrs) do
    link
    |> ParentChild.changeset(Map.take(attrs, ["kind", :kind]))
    |> Repo.update()
  end

  @doc "Deletes a parent/child link"
  def delete_parent_child(%ParentChild{} = link), do: Repo.delete(link)

  @doc "Returns a parent/child link by id"
  def get_parent_child!(id), do: Repo.get!(ParentChild, id)

  # The new link parent -> child forms a cycle if child is already an ancestor of parent.
  defp creates_cycle?(parent_id, child_id) do
    parents_of =
      from(pc in ParentChild, select: {pc.child_id, pc.parent_id})
      |> Repo.all()
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

    ancestor?(parents_of, [parent_id], child_id, MapSet.new())
  end

  defp ancestor?(_parents_of, [], _target, _seen), do: false

  defp ancestor?(parents_of, [id | rest], target, seen) do
    cond do
      id == target ->
        true

      MapSet.member?(seen, id) ->
        ancestor?(parents_of, rest, target, seen)

      true ->
        ancestor?(parents_of, Map.get(parents_of, id, []) ++ rest, target, MapSet.put(seen, id))
    end
  end

  # --- Family: partnerships ---

  @doc "Creates a partnership"
  def create_partnership(attrs) do
    %Partnership{}
    |> Partnership.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Updates a partnership (status only)"
  def update_partnership(%Partnership{} = partnership, attrs) do
    partnership
    |> Partnership.changeset(Map.take(attrs, ["status", :status]))
    |> Repo.update()
  end

  @doc "Deletes a partnership"
  def delete_partnership(%Partnership{} = partnership), do: Repo.delete(partnership)

  @doc "Returns a partnership by id"
  def get_partnership!(id), do: Repo.get!(Partnership, id)

  # --- Family: queries ---

  @doc """
  Returns the direct kin of a character as
  `%{parents: [...], partners: [...], children: [...]}` where each entry is
  `%{link: link, person: %Character{}}`.
  """
  def get_kin(character_id) do
    parents =
      from(pc in ParentChild,
        where: pc.child_id == ^character_id,
        preload: [:parent],
        order_by: pc.inserted_at
      )
      |> Repo.all()
      |> Enum.map(&%{link: &1, person: &1.parent})

    children =
      from(pc in ParentChild,
        where: pc.parent_id == ^character_id,
        preload: [:child],
        order_by: pc.inserted_at
      )
      |> Repo.all()
      |> Enum.map(&%{link: &1, person: &1.child})

    partners =
      from(p in Partnership,
        where: p.partner_a_id == ^character_id or p.partner_b_id == ^character_id,
        preload: [:partner_a, :partner_b],
        order_by: p.inserted_at
      )
      |> Repo.all()
      |> Enum.map(fn p ->
        other = if p.partner_a_id == character_id, do: p.partner_b, else: p.partner_a
        %{link: p, person: other}
      end)

    %{parents: parents, partners: partners, children: children}
  end

  @doc "Returns characters that have at least one family link, ordered by name"
  def list_family_members do
    Repo.all(from(c in Character, where: c.id in subquery(family_member_ids()), order_by: c.name))
  end

  @doc "Returns true if the character has any family link"
  def has_family?(character_id) do
    Repo.exists?(
      from(pc in ParentChild,
        where: pc.parent_id == ^character_id or pc.child_id == ^character_id
      )
    ) or
      Repo.exists?(
        from(p in Partnership,
          where: p.partner_a_id == ^character_id or p.partner_b_id == ^character_id
        )
      )
  end

  @doc "Returns a random character with at least one family link, or nil"
  def random_family_member do
    Repo.one(
      from(c in Character,
        where: c.id in subquery(family_member_ids()),
        order_by: fragment("RANDOM()"),
        limit: 1
      )
    )
  end

  defp family_member_ids do
    parent_ids = from(pc in ParentChild, select: pc.parent_id)
    child_ids = from(pc in ParentChild, select: pc.child_id)
    a_ids = from(p in Partnership, select: p.partner_a_id)
    b_ids = from(p in Partnership, select: p.partner_b_id)

    parent_ids |> union(^child_ids) |> union(^a_ids) |> union(^b_ids)
  end

  @doc """
  Returns the family tree around a character, formatted for the tree
  renderer, or nil if the character does not exist.

  Shows two generations each way from the focus (F):

    * grandparents, parents, children and grandchildren
    * siblings (full and half), aunts/uncles and cousins, each hanging
      only from the parent they share with the bloodline
    * F's own partners, and the other parents of F's children and
      grandchildren

  Anyone else (step-parents, a parent's other partners, cousins' spouses,
  great-grandparents...) is left out, and the people linked to them are
  flagged with `has_more: true`. Empty generations are removed so the
  eldest shown generation is 0.
  """
  def get_family_tree(character_id) do
    with {:ok, uuid} <- Ecto.UUID.cast(character_id),
         %Character{} = focus <- get_character(uuid) do
      build_family_tree(focus.id)
    else
      _ -> nil
    end
  end

  defp build_family_tree(f) do
    parent_links = Repo.all(ParentChild)
    partnerships = Repo.all(Partnership)

    parents_of = Enum.group_by(parent_links, & &1.child_id, & &1.parent_id)
    children_of = Enum.group_by(parent_links, & &1.parent_id, & &1.child_id)

    partners_of =
      Enum.reduce(partnerships, %{}, fn p, acc ->
        acc
        |> Map.update(p.partner_a_id, [p.partner_b_id], &[p.partner_b_id | &1])
        |> Map.update(p.partner_b_id, [p.partner_a_id], &[p.partner_a_id | &1])
      end)

    up = &Enum.flat_map(&1, fn id -> Map.get(parents_of, id, []) end)
    down = &Enum.flat_map(&1, fn id -> Map.get(children_of, id, []) end)

    parents = up.([f])
    grandparents = up.(parents)
    children = down.([f])
    grandchildren = down.(children)
    siblings = down.(parents)
    aunts = down.(grandparents) -- parents
    cousins = down.(aunts)
    partners = Map.get(partners_of, f, [])
    # The other parents of F's children and of F's grandchildren
    co_parents = up.(children)
    grandchild_co_parents = up.(grandchildren) -- children

    # Earlier entries win if someone qualifies twice. Generations are relative
    # to the grandparents' row (0) and compacted below.
    generations =
      [
        {[f], 2},
        {parents, 1},
        {grandparents, 0},
        {children, 3},
        {grandchildren, 4},
        {siblings, 2},
        {aunts, 1},
        {cousins, 2},
        {partners, 2},
        {co_parents, 2},
        {grandchild_co_parents, 3}
      ]
      |> Enum.reduce(%{}, fn {ids, gen}, acc ->
        Enum.reduce(ids, acc, &Map.put_new(&2, &1, gen))
      end)

    shown? = &Map.has_key?(generations, &1)
    rows = generations |> Map.values() |> Enum.uniq() |> Enum.sort()
    row_index = rows |> Enum.with_index() |> Map.new()

    neighbours = fn id ->
      Map.get(parents_of, id, []) ++ Map.get(children_of, id, []) ++ Map.get(partners_of, id, [])
    end

    ids = Map.keys(generations)

    nodes =
      from(c in Character, where: c.id in ^ids, order_by: c.name)
      |> Repo.all()
      |> Enum.map(fn c ->
        %{
          id: c.id,
          name: c.name,
          image_url: c.image_url,
          pc: "pc" in c.tags or "player" in c.tags,
          deceased: "deceased" in c.tags,
          generation: row_index[generations[c.id]],
          has_more: Enum.any?(neighbours.(c.id), &(not shown?.(&1)))
        }
      end)

    %{
      focus_id: f,
      nodes: nodes,
      parent_links:
        for(
          l <- parent_links,
          shown?.(l.parent_id) and shown?.(l.child_id),
          do: %{parent_id: l.parent_id, child_id: l.child_id, kind: l.kind}
        ),
      partnerships:
        for(
          p <- partnerships,
          shown?.(p.partner_a_id) and shown?.(p.partner_b_id),
          do: %{a_id: p.partner_a_id, b_id: p.partner_b_id, status: p.status}
        )
    }
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
