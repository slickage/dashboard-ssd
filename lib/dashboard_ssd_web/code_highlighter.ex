defmodule DashboardSSDWeb.CodeHighlighter do
  @moduledoc """
  Applies Monokai syntax highlighting to Notion code blocks using the Makeup library.

  Falls back to escaped plain text when a lexer for the requested language is not available.
  """

  alias Phoenix.HTML

  @style_name :monokai_style
  @default_language "text"
  @language_aliases %{
    "elixir" => "elixir",
    "ex" => "elixir",
    "exs" => "elixir",
    "iex" => "elixir",
    "erlang" => "erlang",
    "erl" => "erlang",
    "bash" => "bourne_again_shell_bash",
    "sh" => "bourne_again_shell_bash",
    "shell" => "bourne_again_shell_bash",
    "zsh" => "bourne_again_shell_bash",
    "shell-unix" => "bourne_again_shell_bash",
    "json" => "json",
    "javascript" => "javascript",
    "js" => "javascript",
    "ts" => "typescript",
    "typescript" => "typescript",
    "python" => "python",
    "py" => "python",
    "ruby" => "ruby",
    "rb" => "ruby",
    "go" => "go",
    "rust" => "rust",
    "java" => "java",
    "c" => "c",
    "cpp" => "c++",
    "c++" => "c++",
    "csharp" => "c#",
    "c#" => "c#",
    "sql" => "sql",
    "yaml" => "yaml",
    "yml" => "yaml",
    "html" => "html",
    "css" => "css",
    "plaintext" => "plain_text",
    "plain_text" => "plain_text",
    "text" => "plain_text"
  }

  @doc """
  Highlights `code` using the configured Makeup style. When a lexer cannot be
  resolved for the requested `language`, the code is safely HTML escaped.
  """
  @spec highlight(String.t(), String.t() | nil) :: HTML.safe()
  def highlight(code, language \\ nil)

  def highlight(nil, language), do: highlight("", language)

  def highlight(code, language) when is_binary(code) do
    code = code |> normalize_code()

    case lexer_for(language) do
      {:ok, {lexer, lexer_opts}} ->
        highlight =
          Makeup.highlight_inner_html(code,
            lexer: lexer,
            lexer_options: lexer_opts,
            formatter_options: [highlight_tag: "span"],
            style: @style_name
          )

        {:safe, highlight}

      :error ->
        HTML.html_escape(code)
    end
  end

  @doc """
  Normalizes a language token into the CSS class used by the syntax highlighting
  styles. Empty or unknown input falls back to the default language.
  """
  @spec css_language(String.t() | nil) :: String.t()
  def css_language(nil), do: @default_language
  def css_language(""), do: @default_language

  def css_language(language) do
    language
    |> normalized_language_name()
    |> sanitize_css_class()
  end

  defp lexer_for(nil), do: :error
  defp lexer_for(""), do: :error

  defp lexer_for(language) when is_binary(language) do
    language
    |> normalized_language_name()
    |> candidate_names()
    |> Enum.find_value(:error, fn name ->
      case Makeup.Registry.get_lexer_by_name(name) do
        nil -> nil
        {lexer, opts} -> {:ok, {lexer, opts}}
      end
    end)
    |> case do
      :error ->
        extension = normalized_language_name(language)

        case Makeup.Registry.get_lexer_by_extension(extension) do
          nil -> :error
          {lexer, opts} -> {:ok, {lexer, opts}}
        end

      other ->
        other
    end
  end

  defp normalized_language_name(language) do
    language
    |> String.trim()
    |> String.downcase()
    |> (&Map.get(@language_aliases, &1, &1)).()
  end

  defp candidate_names(name) do
    sanitized = String.replace(name, ~r/[^a-z0-9]+/, "_")

    [name, sanitized]
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp sanitize_css_class(name) do
    name
    |> String.replace(~r/[^a-zA-Z0-9]+/, "-")
    |> String.trim("-")
    |> case do
      "" -> @default_language
      value -> value
    end
  end

  defp normalize_code(code) do
    code
    |> String.replace("\r\n", "\n")
    |> String.replace("\r", "\n")
    |> String.trim_leading()
    |> String.trim_trailing()
  end
end
