defmodule Indie.Stonetop.PlaceholderTest do
  use Indie.DataCase, async: true

  alias Indie.Stonetop
  alias Indie.Stonetop.Character

  defp char(name) do
    {:ok, c} = Stonetop.create_character(%{"name" => name})
    c
  end

  defp parent!(parent, child) do
    {:ok, _} = Stonetop.create_parent_child(%{"parent_id" => parent.id, "child_id" => child.id})
  end

  defp parent_ids(child), do: Stonetop.get_kin(child.id).parents |> Enum.map(& &1.person.id)

  describe "add_sibling/2" do
    test "creates a placeholder parent shared by both when neither has parents" do
      [a, b] = [char("A"), char("B")]
      assert {:ok, _} = Stonetop.add_sibling(a.id, b.id)

      assert [p] = parent_ids(a)
      assert parent_ids(b) == [p]
      assert %Character{placeholder: true} = Stonetop.get_character(p)
    end

    test "reuses the person's existing parents instead of creating a placeholder" do
      [mum, dad, a, b] = Enum.map(~w(Mum Dad A B), &char/1)
      parent!(mum, a)
      parent!(dad, a)

      assert {:ok, _} = Stonetop.add_sibling(a.id, b.id)
      assert Enum.sort(parent_ids(b)) == Enum.sort([mum.id, dad.id])
      refute Enum.any?(Repo.all(Character), & &1.placeholder)
    end

    test "a third sibling joins the same placeholder" do
      [a, b, c] = Enum.map(~w(A B C), &char/1)
      {:ok, _} = Stonetop.add_sibling(a.id, b.id)
      {:ok, _} = Stonetop.add_sibling(b.id, c.id)

      assert parent_ids(a) == parent_ids(c)
      assert Enum.count(Repo.all(Character), & &1.placeholder) == 1
    end

    test "rejects adding yourself or an existing sibling" do
      [a, b] = [char("A"), char("B")]
      assert {:error, _} = Stonetop.add_sibling(a.id, a.id)
      {:ok, _} = Stonetop.add_sibling(a.id, b.id)
      assert {:error, "is already a sibling"} = Stonetop.add_sibling(a.id, b.id)
    end
  end

  describe "get_kin/1 siblings" do
    test "lists siblings and marks those linked only through a placeholder as removable" do
      [mum, a, b, c] = Enum.map(~w(Mum A B C), &char/1)
      parent!(mum, a)
      parent!(mum, b)
      {:ok, _} = Stonetop.add_sibling(a.id, c.id)

      sibs = Map.new(Stonetop.get_kin(a.id).siblings, &{&1.person.name, &1.removable})
      assert sibs == %{"B" => false, "C" => false}

      [x, y] = [char("X"), char("Y")]
      {:ok, _} = Stonetop.add_sibling(x.id, y.id)
      assert [%{person: %{name: "Y"}, removable: true}] = Stonetop.get_kin(x.id).siblings
    end
  end

  describe "remove_sibling/2" do
    test "unlinks the sibling and deletes the placeholder once it has one child left" do
      [a, b] = [char("A"), char("B")]
      {:ok, _} = Stonetop.add_sibling(a.id, b.id)
      [p] = parent_ids(a)

      assert :ok = Stonetop.remove_sibling(a.id, b.id)
      assert Stonetop.get_kin(a.id).siblings == []
      assert parent_ids(a) == []
      assert Stonetop.get_character(p) == nil
    end

    test "keeps the placeholder while two or more children remain" do
      [a, b, c] = Enum.map(~w(A B C), &char/1)
      {:ok, _} = Stonetop.add_sibling(a.id, b.id)
      {:ok, _} = Stonetop.add_sibling(a.id, c.id)

      :ok = Stonetop.remove_sibling(a.id, c.id)
      assert [%{person: %{name: "B"}}] = Stonetop.get_kin(a.id).siblings
    end
  end

  describe "resolving a placeholder" do
    setup do
      [a, b] = [char("A"), char("B")]
      {:ok, _} = Stonetop.add_sibling(a.id, b.id)
      [p] = parent_ids(a)
      %{a: a, b: b, placeholder: Stonetop.get_character(p)}
    end

    test "name_placeholder turns it into a real character", %{a: a, placeholder: p} do
      assert {:ok, named} = Stonetop.name_placeholder(p, "Old Hesketh")
      assert named.name == "Old Hesketh"
      refute named.placeholder
      assert parent_ids(a) == [p.id]
      assert "Old Hesketh" in Enum.map(Stonetop.list_characters(), & &1.name)
    end

    test "name_placeholder requires a name", %{placeholder: p} do
      assert {:error, _} = Stonetop.name_placeholder(p, "")
    end

    test "merge_placeholder moves the children to an existing character", %{
      a: a,
      b: b,
      placeholder: p
    } do
      mum = char("Mum")
      assert {:ok, _} = Stonetop.merge_placeholder(p, mum.id)
      assert parent_ids(a) == [mum.id]
      assert parent_ids(b) == [mum.id]
      assert Stonetop.get_character(p.id) == nil
    end

    test "merge_placeholder skips children already linked to the target", %{
      a: a,
      b: b,
      placeholder: p
    } do
      mum = char("Mum")
      parent!(mum, a)
      assert {:ok, _} = Stonetop.merge_placeholder(p, mum.id)
      assert parent_ids(a) == [mum.id]
      assert parent_ids(b) == [mum.id]
    end

    test "merge_placeholder refuses one of its own children", %{a: a, placeholder: p} do
      assert {:error, _} = Stonetop.merge_placeholder(p, a.id)
      assert Stonetop.get_character(p.id)
    end
  end

  describe "placeholders stay out of sight" do
    setup do
      [a, b] = [char("A"), char("B")]
      {:ok, _} = Stonetop.add_sibling(a.id, b.id)
      %{a: a, placeholder_id: hd(parent_ids(a))}
    end

    test "not listed, not in the graph, not random, not found by slug", %{placeholder_id: p} do
      refute p in Enum.map(Stonetop.list_characters(), & &1.id)
      refute p in Enum.map(Stonetop.list_family_members(), & &1.id)
      refute p in Enum.map(Stonetop.get_graph_data().nodes, & &1.id)
      refute Stonetop.get_character_by_slug("unknown-parent")
      refute Stonetop.get_character_by_slug(p)
      for _ <- 1..10, do: assert(Stonetop.random_character().id != p)
    end

    test "the tree includes it as hidden, and it never causes a ☞", %{a: a, placeholder_id: p} do
      tree = Stonetop.get_family_tree(a.id)
      nodes = Map.new(tree.nodes, &{&1.id, &1})

      assert nodes[p].hidden
      refute nodes[a.id].hidden
      refute Enum.any?(tree.nodes, & &1.has_more)
      assert length(tree.parent_links) == 2
    end

    test "a placeholder is not a valid tree focus", %{placeholder_id: p} do
      assert Stonetop.get_family_tree(p) == nil
    end
  end
end
