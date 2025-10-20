defmodule DashboardSSDWeb.CodeHighlighterTest do
  use ExUnit.Case, async: true

  alias DashboardSSDWeb.CodeHighlighter

  describe "highlight/2" do
    test "returns safe HTML for supported language" do
      {:safe, html} = CodeHighlighter.highlight("IO.inspect(:ok)\n", "elixir")
      html = IO.iodata_to_binary(html)

      assert String.starts_with?(html, "<span class=\"nc\">IO")
    end

    test "escapes code when language is unknown" do
      {:safe, html} = CodeHighlighter.highlight("<script>alert('xss')</script>", "unknown")
      html = IO.iodata_to_binary(html)

      refute String.contains?(html, "<script>")
      assert String.contains?(html, "&lt;script&gt;")
    end

    test "normalizes indentation" do
      code = "    echo hello\n    echo world\n"
      {:safe, html} = CodeHighlighter.highlight(code, "bash")
      html = IO.iodata_to_binary(html)

      assert String.starts_with?(html, "<span class=\"nf\">echo")
      refute String.starts_with?(html, "    ")
    end

    test "handles nil input and unknown language gracefully" do
      {:safe, html} = CodeHighlighter.highlight(nil, nil)
      assert IO.iodata_to_binary(html) == ""
    end

    test "treats empty language as plain text" do
      {:safe, html} = CodeHighlighter.highlight("plain", "")
      assert IO.iodata_to_binary(html) == "plain"
    end

    test "falls back to lexer extension lookup" do
      {:safe, html} = CodeHighlighter.highlight("console.log('hi')", "js")
      assert IO.iodata_to_binary(html) =~ "console"
    end
  end

  describe "css_language/1" do
    test "returns default when nil" do
      assert CodeHighlighter.css_language(nil) == "text"
    end

    test "sanitizes known aliases" do
      assert CodeHighlighter.css_language("bash") == "bourne-again-shell-bash"
    end

    test "normalizes whitespace and punctuation" do
      assert CodeHighlighter.css_language(" GraphQL Schema ") == "graphql-schema"
    end

    test "falls back to default when css class would be empty" do
      assert CodeHighlighter.css_language("!!!") == "text"
    end

    test "returns default for empty string" do
      assert CodeHighlighter.css_language("") == "text"
    end
  end
end
