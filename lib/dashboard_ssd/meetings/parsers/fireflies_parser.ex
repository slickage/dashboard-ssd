defmodule DashboardSSD.Meetings.Parsers.FirefliesParser do
  @moduledoc """
  Utilities for parsing Fireflies summaries into structured segments used by the
  Meetings feature.

  The parser splits the summary at the first case-insensitive heading matching
  "Action Items". Content before that heading is treated as the "accomplished"
  narrative; content after is split into individual items for the next agenda.
  """

  @type parsed :: %{
          accomplished: String.t() | nil,
          action_items: [String.t()]
        }

  @doc """
  Splits a Fireflies summary text into accomplished and action items sections.

  Returns a map with keys `:accomplished` and `:action_items`.
  """
  @spec split_summary(String.t() | nil) :: {:ok, parsed()}
  def split_summary(nil), do: {:ok, %{accomplished: nil, action_items: []}}

  def split_summary(summary) when is_binary(summary) do
    {accomplished, actions_text} = do_split(summary)
    # Structured logging for observability
    _ =
      Logger.debug(fn ->
        %{msg: "fireflies_parser.split_summary", accomplished_size: byte_size(accomplished || ""), has_action_items: actions_text != ""}
        |> Jason.encode!()
      end)
    items =
      actions_text
      |> split_lines()
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    {:ok, %{accomplished: accomplished, action_items: items}}
  end

  defp do_split(text) do
    # Split on first occurrence of a line that begins with "Action Items"
    regex = ~r/(.*?)(\n+|\A)\s*Action\s*Items\s*:?(.*)\z/ims

    case Regex.run(regex, text) do
      nil -> {String.trim(text), ""}
      [_, before, _sep, after_text] -> {String.trim(before), String.trim(after_text)}
    end
  end

  defp split_lines(""), do: []
  defp split_lines(text) do
    text
    |> String.split(["\n", "\r\n"], trim: true)
  end
end
