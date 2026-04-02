defmodule Indie.Markdown.HighlightTransformerTest do
  use ExUnit.Case, async: true

  alias Indie.Markdown.HighlightTransformer

  describe "transform/1" do
    test "single yellow highlight in a paragraph" do
      ast = [{"p", [], ["Hello ==yellow:world== there"], %{}}]
      result = HighlightTransformer.transform(ast)

      assert [{"p", [], ["Hello ", mark, " there"], %{}}] = result
      assert {"mark", [{"style", style}], ["world"], %{}} = mark
      assert style =~ "rgba(255,255,0"
      assert style =~ "filter: url(#hl-handdrawn)"
    end

    test "single green highlight" do
      ast = [{"p", [], ["==green:some text=="], %{}}]
      [{"p", [], [mark], %{}}] = HighlightTransformer.transform(ast)
      assert {"mark", [{"style", style}], ["some text"], %{}} = mark
      assert style =~ "rgba(0,200,100"
    end

    test "single blue highlight" do
      ast = [{"p", [], ["==blue:some text=="], %{}}]
      [{"p", [], [mark], %{}}] = HighlightTransformer.transform(ast)
      assert {"mark", [{"style", style}], ["some text"], %{}} = mark
      assert style =~ "rgba(0,150,255"
    end

    test "single red highlight" do
      ast = [{"p", [], ["==red:some text=="], %{}}]
      [{"p", [], [mark], %{}}] = HighlightTransformer.transform(ast)
      assert {"mark", [{"style", style}], ["some text"], %{}} = mark
      assert style =~ "rgba(255,60,60"
    end

    test "multiple highlights of different colors in same paragraph" do
      ast = [{"p", [], ["==yellow:one== and ==blue:two=="], %{}}]
      [{"p", [], children, %{}}] = HighlightTransformer.transform(ast)

      assert [yellow_mark, " and ", blue_mark] = children
      assert {"mark", [{"style", yellow_style}], ["one"], %{}} = yellow_mark
      assert {"mark", [{"style", blue_style}], ["two"], %{}} = blue_mark
      assert yellow_style =~ "rgba(255,255,0"
      assert blue_style =~ "rgba(0,150,255"
    end

    test "adjacent highlights with no text between them" do
      ast = [{"p", [], ["==red:first====green:second=="], %{}}]
      [{"p", [], children, %{}}] = HighlightTransformer.transform(ast)

      assert [red_mark, green_mark] = children
      assert {"mark", [{"style", _}], ["first"], %{}} = red_mark
      assert {"mark", [{"style", _}], ["second"], %{}} = green_mark
    end

    test "highlight spanning multiple words" do
      ast = [{"p", [], ["==yellow:hello world foo=="], %{}}]
      [{"p", [], [mark], %{}}] = HighlightTransformer.transform(ast)
      assert {"mark", [{"style", _}], ["hello world foo"], %{}} = mark
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
