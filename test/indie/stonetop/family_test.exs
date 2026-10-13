defmodule Indie.Stonetop.FamilyTest do
  use Indie.DataCase, async: true

  alias Indie.Stonetop
  alias Indie.Stonetop.{ParentChild, Partnership}

  defp char(name, tags \\ []) do
    {:ok, c} = Stonetop.create_character(%{"name" => name, "tags" => tags})
    c
  end

  defp parent!(parent, child, kind \\ "biological") do
    {:ok, pc} =
      Stonetop.create_parent_child(%{
        "parent_id" => parent.id,
        "child_id" => child.id,
        "kind" => kind
      })

    pc
  end

  defp partners!(a, b, status \\ "married") do
    {:ok, p} =
      Stonetop.create_partnership(%{
        "partner_a_id" => a.id,
        "partner_b_id" => b.id,
        "status" => status
      })

    p
  end

  describe "parent/child links" do
    test "creates a link with a kind" do
      [p, c] = [char("Maeve"), char("Aldric")]
      assert %ParentChild{kind: "adopted"} = parent!(p, c, "adopted")
    end

    test "rejects self links" do
      p = char("Maeve")

      assert {:error, cs} =
               Stonetop.create_parent_child(%{"parent_id" => p.id, "child_id" => p.id})

      assert "cannot be own parent" in errors_on(cs).child_id
    end

    test "rejects unknown kinds" do
      [p, c] = [char("Maeve"), char("Aldric")]

      assert {:error, cs} =
               Stonetop.create_parent_child(%{
                 "parent_id" => p.id,
                 "child_id" => c.id,
                 "kind" => "goblin"
               })

      assert errors_on(cs).kind
    end

    test "rejects duplicates" do
      [p, c] = [char("Maeve"), char("Aldric")]
      parent!(p, c)

      assert {:error, cs} =
               Stonetop.create_parent_child(%{"parent_id" => p.id, "child_id" => c.id})

      assert errors_on(cs).parent_id
    end

    test "rejects cycles" do
      [g, p, c] = [char("Grand"), char("Parent"), char("Child")]
      parent!(g, p)
      parent!(p, c)

      assert {:error, cs} =
               Stonetop.create_parent_child(%{"parent_id" => c.id, "child_id" => g.id})

      assert "would make someone their own ancestor" in errors_on(cs).child_id
    end

    test "deletes a link" do
      [p, c] = [char("Maeve"), char("Aldric")]
      link = parent!(p, c)
      assert {:ok, _} = Stonetop.delete_parent_child(link)
      assert Stonetop.get_kin(c.id).parents == []
    end
  end

  describe "partnerships" do
    test "stores the pair in sorted order" do
      [a, b] = [char("A"), char("B")]
      p = partners!(a, b)
      assert p.partner_a_id < p.partner_b_id
    end

    test "rejects the reversed duplicate" do
      [a, b] = [char("A"), char("B")]
      partners!(a, b)

      assert {:error, cs} =
               Stonetop.create_partnership(%{"partner_a_id" => b.id, "partner_b_id" => a.id})

      assert errors_on(cs).partner_a_id
    end

    test "rejects self partnership" do
      a = char("A")

      assert {:error, cs} =
               Stonetop.create_partnership(%{"partner_a_id" => a.id, "partner_b_id" => a.id})

      assert errors_on(cs).partner_b_id
    end

    test "updates status" do
      [a, b] = [char("A"), char("B")]
      p = partners!(a, b)

      assert {:ok, %Partnership{status: "divorced"}} =
               Stonetop.update_partnership(p, %{"status" => "divorced"})
    end
  end

  describe "get_kin/1" do
    test "returns parents, partners and children with the other person loaded" do
      [m, f, me, spouse, kid] = Enum.map(~w(Mum Dad Me Spouse Kid), &char/1)
      parent!(m, me)
      parent!(f, me)
      partners!(me, spouse)
      parent!(me, kid)

      kin = Stonetop.get_kin(me.id)
      assert kin.parents |> Enum.map(& &1.person.name) |> Enum.sort() == ["Dad", "Mum"]
      assert Enum.map(kin.partners, & &1.person.name) == ["Spouse"]
      assert Enum.map(kin.children, & &1.person.name) == ["Kid"]
    end
  end

  describe "family members" do
    test "list_family_members only includes linked characters" do
      [a, b] = [char("Bea"), char("Al")]
      _loner = char("Loner")
      parent!(a, b)
      assert Enum.map(Stonetop.list_family_members(), & &1.name) == ["Al", "Bea"]
    end

    test "random_character returns nil when there are no characters" do
      assert Stonetop.random_character() == nil
    end

    test "random_character returns any character, with or without family" do
      loner = char("Loner")
      assert Stonetop.random_character().id == loner.id
    end
  end

  describe "get_family_tree/1" do
    defp gens(tree), do: Map.new(tree.nodes, &{&1.name, &1.generation})
    defp names(tree), do: tree.nodes |> Enum.map(& &1.name) |> Enum.sort()

    defp more(tree),
      do: tree.nodes |> Enum.filter(& &1.has_more) |> Enum.map(& &1.name) |> Enum.sort()

    defp link?(tree, parent, child),
      do: Enum.any?(tree.parent_links, &(&1.parent_id == parent.id and &1.child_id == child.id))

    test "returns nil for an unknown id" do
      assert Stonetop.get_family_tree(Ecto.UUID.generate()) == nil
    end

    test "a character with no links is a one-node tree" do
      a = char("Loner")
      tree = Stonetop.get_family_tree(a.id)
      assert [%{id: id, generation: 0}] = tree.nodes
      assert id == a.id
    end

    test "shows grandparents, parents, aunts and the focus, hiding a parent's other partner" do
      [gm, gf, aldric, wren, isolde, pip] =
        Enum.map(~w(Maeve Corwin Aldric Wren Isolde Pip), &char/1)

      parent!(gm, aldric)
      parent!(gf, aldric)
      parent!(gm, wren)
      partners!(gm, gf)
      partners!(aldric, isolde)
      parent!(aldric, pip)
      _stranger = char("Stranger")

      tree = Stonetop.get_family_tree(pip.id)

      assert gens(tree) == %{
               "Maeve" => 0,
               "Corwin" => 0,
               "Aldric" => 1,
               "Wren" => 1,
               "Pip" => 2
             }

      assert tree.focus_id == pip.id
      assert length(tree.parent_links) == 4
      assert length(tree.partnerships) == 1
      assert more(tree) == ["Aldric"]
    end

    test "half-siblings hang from the shared parent; the step-parent is hidden" do
      [mum, dad1, dad2, a, b] = Enum.map(~w(Mum Dad1 Dad2 A B), &char/1)
      partners!(mum, dad1, "divorced")
      partners!(mum, dad2)
      parent!(mum, a)
      parent!(dad1, a)
      parent!(mum, b)
      parent!(dad2, b)

      tree = Stonetop.get_family_tree(a.id)
      assert gens(tree) == %{"Mum" => 0, "Dad1" => 0, "A" => 1, "B" => 1}
      assert link?(tree, mum, b)
      refute Enum.any?(tree.partnerships, &(dad2.id in [&1.a_id, &1.b_id]))
      assert more(tree) == ["B", "Mum"]
    end

    test "the Brindle example: parted parents, mother remarries and has another child" do
      [ollo, mags, brindle, lark, newchild] =
        Enum.map(~w(Ollo Mags Brindle Lark Newchild), &char/1)

      partners!(ollo, mags, "divorced")
      parent!(ollo, brindle)
      parent!(mags, brindle)
      partners!(mags, lark)
      parent!(mags, newchild)
      parent!(lark, newchild)

      tree = Stonetop.get_family_tree(brindle.id)
      assert names(tree) == ~w(Brindle Mags Newchild Ollo)
      assert link?(tree, mags, newchild)
      refute link?(tree, lark, newchild)
    end

    test "includes aunts, uncles and cousins but not the cousins' other parent or children" do
      [gm, gf, dad, aunt, uncle_in_law, me, cousin, cousins_kid] =
        Enum.map(~w(Gm Gf Dad Aunt Inlaw Me Cousin CousinsKid), &char/1)

      partners!(gm, gf)
      for c <- [dad, aunt], p <- [gm, gf], do: parent!(p, c)
      parent!(dad, me)
      partners!(aunt, uncle_in_law)
      parent!(aunt, cousin)
      parent!(uncle_in_law, cousin)
      parent!(cousin, cousins_kid)

      tree = Stonetop.get_family_tree(me.id)
      assert names(tree) == ~w(Aunt Cousin Dad Gf Gm Me)
      assert gens(tree)["Cousin"] == gens(tree)["Me"]
      assert "Cousin" in more(tree)
      assert "Aunt" in more(tree)
    end

    test "stops at two generations each way" do
      [ggp, gp, p, me, c, gc, ggc] = Enum.map(~w(GGP GP P Me C GC GGC), &char/1)
      parent!(ggp, gp)
      parent!(gp, p)
      parent!(p, me)
      parent!(me, c)
      parent!(c, gc)
      parent!(gc, ggc)

      tree = Stonetop.get_family_tree(me.id)
      assert gens(tree) == %{"GP" => 0, "P" => 1, "Me" => 2, "C" => 3, "GC" => 4}
      assert more(tree) == ["GC", "GP"]
    end

    test "shows the focus's partners and the co-parents of children and grandchildren" do
      [me, ex, kid_other_parent, kid, kid_spouse, grandkid, kid_ex] =
        Enum.map(~w(Me Ex Other Kid Spouse Grandkid KidEx), &char/1)

      partners!(me, ex, "divorced")
      parent!(me, kid)
      parent!(kid_other_parent, kid)
      partners!(kid, kid_spouse)
      parent!(kid, grandkid)
      parent!(kid_spouse, grandkid)
      partners!(kid, kid_ex, "divorced")

      tree = Stonetop.get_family_tree(me.id)
      assert names(tree) == ~w(Ex Grandkid Kid Me Other Spouse)

      assert gens(tree) == %{
               "Me" => 0,
               "Ex" => 0,
               "Other" => 0,
               "Kid" => 1,
               "Spouse" => 1,
               "Grandkid" => 2
             }

      assert more(tree) == ["Kid"]
    end

    test "separate families stay separate" do
      [a, b, c, d] = Enum.map(~w(A B C D), &char/1)
      parent!(a, b)
      parent!(c, d)
      names = Stonetop.get_family_tree(a.id).nodes |> Enum.map(& &1.name) |> Enum.sort()
      assert names == ["A", "B"]
    end

    test "marks pc and deceased from tags" do
      [a, b] = [char("A", ["pc"]), char("B", ["deceased"])]
      parent!(b, a)
      nodes = Map.new(Stonetop.get_family_tree(a.id).nodes, &{&1.name, &1})
      assert nodes["A"].pc and not nodes["A"].deceased
      assert nodes["B"].deceased and not nodes["B"].pc
    end
  end
end
