defmodule DashboardSSD.Meetings.AgendaMoreTest do
  use DashboardSSD.DataCase, async: false

  alias DashboardSSD.Meetings.Agenda
  alias DashboardSSD.Meetings.AgendaItem

  setup do
    # Ensure Fireflies auth present for GraphQL client paths
    prev = Application.get_env(:dashboard_ssd, :integrations)
    Application.put_env(:dashboard_ssd, :integrations, Keyword.merge(prev || [], fireflies_api_token: "tok"))

    on_exit(fn ->
      if prev,
        do: Application.put_env(:dashboard_ssd, :integrations, prev),
        else: Application.delete_env(:dashboard_ssd, :integrations)
    end)

    :ok
  end

  test "derive_items_for_event returns [] when series_id is nil" do
    assert [] == Agenda.derive_items_for_event("evt-none", nil, [])
  end

  test "merged_items_for_event de-duplicates manual and derived items (case/space-insensitive)" do
    event_id = "evt-dedup"
    series_id = "series-dedup"

    {:ok, _} =
      %AgendaItem{}
      |> AgendaItem.changeset(%{calendar_event_id: event_id, text: "Action One", position: 0, source: "manual"})
      |> DashboardSSD.Repo.insert()

    {:ok, _} =
      %AgendaItem{}
      |> AgendaItem.changeset(%{calendar_event_id: event_id, text: "action   one   ", position: 1, source: "manual"})
      |> DashboardSSD.Repo.insert()

    # Mock Fireflies bits and transcript for derived items
    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.fireflies.ai/graphql", body: body} ->
        payload = if is_binary(body), do: Jason.decode!(body), else: body
        query = Map.get(payload, "query") || Map.get(payload, :query)
        vars = Map.get(payload, "variables") || %{}

        cond do
          is_binary(query) and String.contains?(query, "query Bites") ->
            %Tesla.Env{status: 200, body: %{"data" => %{"bites" => [
              %{"id" => "b1", "transcript_id" => "t1", "created_at" => "2024-01-01T00:00:00Z", "created_from" => %{"id" => series_id}}
            ]}}}

          is_binary(query) and String.contains?(query, "query Transcript(") and (vars["transcriptId"] == "t1" or vars[:transcriptId] == "t1") ->
            %Tesla.Env{status: 200, body: %{"data" => %{"transcript" => %{"summary" => %{"overview" => nil, "action_items" => ["ACTION   ONE", "Two"], "bullet_gist" => nil}}}}}

          true -> flunk("unexpected request: #{inspect(payload)}")
        end
    end)

    merged = Agenda.merged_items_for_event(event_id, series_id, [])
    # Should contain unique of "Action One" (from manual) and "Two"
    texts = Enum.map(merged, & &1.text)
    assert "Action One" in texts
    assert "Two" in texts
    # Only one variant of "action one" present
    assert Enum.count(texts, &String.contains?(&1, "Action One")) == 1
  end
end

