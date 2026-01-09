defmodule DashboardSSD.Meetings.NotesBatchOptimizationTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Meetings.Notes

  setup do
    prev = Application.get_env(:dashboard_ssd, :integrations)

    Application.put_env(
      :dashboard_ssd,
      :integrations,
      Keyword.merge(prev || [], fireflies_api_token: "tok")
    )

    on_exit(fn ->
      if prev,
        do: Application.put_env(:dashboard_ssd, :integrations, prev),
        else: Application.delete_env(:dashboard_ssd, :integrations)
    end)

    :ok
  end

  test "get_or_fetch_many performs a single remote batch call" do
    base = ~U[2025-12-20 12:00:00Z]
    ev1 = %{id: "evt-1", starts_at: base, ends_at: DateTime.add(base, 3600, :second), title: "A"}

    ev2 = %{
      id: "evt-2",
      starts_at: DateTime.add(base, 7200, :second),
      ends_at: DateTime.add(base, 10_800, :second),
      title: "B"
    }

    parent = self()

    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.fireflies.ai/graphql", body: body} ->
        send(parent, :graphql_called)
        payload = if is_binary(body), do: Jason.decode!(body), else: body
        query = Map.get(payload, "query") || Map.get(payload, :query)

        if is_binary(query) and String.contains?(query, "query Transcripts(") do
          %Tesla.Env{
            status: 200,
            body: %{
              "data" => %{
                "transcripts" => [
                  %{
                    "id" => "t-a",
                    "title" => "A",
                    "date" => DateTime.to_iso8601(base),
                    "summary" => %{"overview" => "A-notes", "action_items" => []}
                  },
                  %{
                    "id" => "t-b",
                    "title" => "B",
                    "date" => DateTime.to_iso8601(DateTime.add(base, 7200, :second)),
                    "summary" => %{"overview" => "B-notes", "action_items" => []}
                  }
                ]
              }
            }
          }
        else
          flunk("unexpected request: #{inspect(payload)}")
        end
    end)

    assert {:ok, map} = Notes.get_or_fetch_many([ev1, ev2])
    assert map["evt-1"].accomplished == "A-notes"
    assert map["evt-2"].accomplished == "B-notes"

    # Exactly one GraphQL call for the batch
    assert_receive :graphql_called, 100
    refute_receive :graphql_called, 50
  end
end
