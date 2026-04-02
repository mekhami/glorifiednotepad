defmodule Indie.Markdown.HighlightTransformerTest do
  use ExUnit.Case, async: true

  alias Indie.Markdown.HighlightTransformer

  describe "transform/1" do
    test "single yellow highlight in a paragraph" do
      ast = [{"p", [], ["Hello ==yellow:world== there"], %{}}]
      result = HighlightTransformer.transform(ast)

      assert [{"p", [], ["Hello ", mark, " there"], %{}}] = result
      assert {"mark", [{"class", "hl-yellow"}], ["world"], %{}} = mark
    end

    test "single green highlight" do
      ast = [{"p", [], ["==green:some text=="], %{}}]
      [{"p", [], [mark], %{}}] = HighlightTransformer.transform(ast)
      assert {"mark", [{"class", "hl-green"}], ["some text"], %{}} = mark
    end

    test "single blue highlight" do
      ast = [{"p", [], ["==blue:some text=="], %{}}]
      [{"p", [], [mark], %{}}] = HighlightTransformer.transform(ast)
      assert {"mark", [{"class", "hl-blue"}], ["some text"], %{}} = mark
    end

    test "single red highlight" do
      ast = [{"p", [], ["==red:some text=="], %{}}]
      [{"p", [], [mark], %{}}] = HighlightTransformer.transform(ast)
      assert {"mark", [{"class", "hl-red"}], ["some text"], %{}} = mark
    end

    test "multiple highlights of different colors in same paragraph" do
      ast = [{"p", [], ["==yellow:one== and ==blue:two=="], %{}}]
      [{"p", [], children, %{}}] = HighlightTransformer.transform(ast)

      assert [yellow_mark, " and ", blue_mark] = children
      assert {"mark", [{"class", "hl-yellow"}], ["one"], %{}} = yellow_mark
      assert {"mark", [{"class", "hl-blue"}], ["two"], %{}} = blue_mark
    end

    test "adjacent highlights with no text between them" do
      ast = [{"p", [], ["==red:first====green:second=="], %{}}]
      [{"p", [], children, %{}}] = HighlightTransformer.transform(ast)

      assert [red_mark, green_mark] = children
      assert {"mark", [{"class", "hl-red"}], ["first"], %{}} = red_mark
      assert {"mark", [{"class", "hl-green"}], ["second"], %{}} = green_mark
    end

    test "highlight spanning multiple words" do
      ast = [{"p", [], ["==yellow:hello world foo=="], %{}}]
      [{"p", [], [mark], %{}}] = HighlightTransformer.transform(ast)
      assert {"mark", [{"class", "hl-yellow"}], ["hello world foo"], %{}} = mark
    end

    test "unknown color passes through unchanged" do
      ast = [{"p", [], ["==purple:text=="], %{}}]
      result = HighlightTransformer.transform(ast)
      assert [{"p", [], ["==purple:text=="], %{}}] = result
    end

    test "highlight syntax inside a code span is not transformed" do
      ast = [{"p", [], [{"code", [], ["==yellow:text=="], %{}}], %{}}]
      result = HighlightTransformer.transform(ast)
      assert [{"p", [], [{"code", [], ["==yellow:text=="], %{}}], %{}}] = result
    end

    test "highlight syntax inside a fenced code block is not transformed" do
      ast = [{"pre", [], [{"code", [], ["==yellow:text=="], %{}}], %{}}]
      result = HighlightTransformer.transform(ast)
      assert [{"pre", [], [{"code", [], ["==yellow:text=="], %{}}], %{}}] = result
    end

    test "plain text with no highlights passes through unchanged" do
      ast = [{"p", [], ["nothing to see here"], %{}}]
      result = HighlightTransformer.transform(ast)
      assert [{"p", [], ["nothing to see here"], %{}}] = result
    end
  end
end
