defmodule DashboardSSD.Integrations.FirefliesBoundaryTest do
  use DashboardSSD.DataCase, async: false

  import Ecto.Query
  alias DashboardSSD.Repo
  alias DashboardSSD.Integrations.Fireflies
  alias DashboardSSD.Meetings.{FirefliesArtifact, CacheStore}

  setup do
    # Ensure token configured
    prev = Application.get_env(:dashboard_ssd, :integrations)

    Application.put_env(
      :dashboard_ssd,
      :integrations,
      Keyword.merge(prev || [], fireflies_api_token: "tok")
    )

    # Reset cache for deterministic tests
    CacheStore.reset()

    on_exit(fn ->
      if prev,
        do: Application.put_env(:dashboard_ssd, :integrations, prev),
        else: Application.delete_env(:dashboard_ssd, :integrations)

      CacheStore.reset()
    end)

    :ok
  end

  test "API fetch persists to DB and caches result" do
    series_id = "series-1"

    # Mock Fireflies GraphQL for bites and transcript summary
    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.fireflies.ai/graphql", body: body} ->
        payload = if is_binary(body), do: Jason.decode!(body), else: body
        query = Map.get(payload, :query) || Map.get(payload, "query")
        vars = Map.get(payload, :variables) || Map.get(payload, "variables") || %{}

        cond do
          is_binary(query) and String.contains?(query, "query Bites") ->
            %Tesla.Env{
              status: 200,
              body: %{
                "data" => %{
                  "bites" => [
                    %{
                      "id" => "b1",
                      "transcript_id" => "t1",
                      "created_at" => "2024-01-01T00:00:00Z",
                      "created_from" => %{"id" => series_id, "name" => "Weekly"}
                    }
                  ]
                }
              }
            }

          is_binary(query) and String.contains?(query, "query Transcript(") and
              (Map.get(vars, "transcriptId") == "t1" or Map.get(vars, :transcriptId) == "t1") ->
            %Tesla.Env{
              status: 200,
              body: %{
                "data" => %{
                  "transcript" => %{
                    "summary" => %{
                      "overview" => "Last meeting notes",
                      "action_items" => ["Do X"],
                      "bullet_gist" => "• Do X"
                    }
                  }
                }
              }
            }

          true ->
            flunk("unexpected request: #{inspect(body)}")
        end
    end)

    # First call should hit API, persist to DB, and cache result
    assert {:ok, %{accomplished: notes, action_items: items}} =
             Fireflies.fetch_latest_for_series(series_id, title: "Weekly")

    assert is_binary(notes) and String.contains?(notes, "Last meeting")
    assert items == ["Do X"]

    # Verify DB persisted
    rec =
      Repo.one(from a in FirefliesArtifact, where: a.recurring_series_id == ^series_id, limit: 1)

    assert rec && rec.transcript_id == "t1"
    assert rec.accomplished == notes
    assert rec.action_items == %{"items" => ["Do X"]}

    # Replace HTTP mock to ensure no further calls occur (cache hit expected)
    Tesla.Mock.mock(fn _ -> flunk("HTTP should not be called on cache hit") end)

    # Second call should return from cache (no HTTP)
    assert {:ok, %{accomplished: notes2, action_items: ["Do X"]}} =
             Fireflies.fetch_latest_for_series(series_id, title: "Weekly")

    assert notes2 == notes
  end

  test "DB fallback returns when cache empty without calling API" do
    series_id = "series-db"

    # Seed DB with an artifact
    {:ok, _rec} =
      %FirefliesArtifact{}
      |> FirefliesArtifact.changeset(%{
        recurring_series_id: series_id,
        transcript_id: "t-db",
        accomplished: "Persisted notes",
        action_items: ["A", "B"],
        bullet_gist: "• A\n• B",
        fetched_at: DateTime.utc_now()
      })
      |> Repo.insert()

    # Clear ETS cache to force DB read path
    CacheStore.flush()

    # Any HTTP call would be a failure here
    Tesla.Mock.mock(fn _ -> flunk("HTTP should not be called when DB has data") end)

    assert {:ok, %{accomplished: "Persisted notes", action_items: ["A", "B"]}} =
             Fireflies.fetch_latest_for_series(series_id, title: "Whatever")
  end
end
