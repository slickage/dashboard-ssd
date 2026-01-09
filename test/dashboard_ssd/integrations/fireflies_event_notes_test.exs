defmodule DashboardSSD.Integrations.FirefliesEventNotesTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Integrations.Fireflies

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

  test "fetch_notes_for_event selects by meeting_link when available" do
    now = ~U[2025-12-11 17:00:00Z]

    ev = %{
      id: "evt-ml",
      starts_at: now,
      ends_at: DateTime.add(now, 3600, :second),
      title: "Weekly Sync",
      participants: ["a@example.com"],
      meeting_link: "https://meet.google.com/abc"
    }

    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.fireflies.ai/graphql", body: body} ->
        payload = if is_binary(body), do: Jason.decode!(body), else: body
        query = Map.get(payload, "query") || Map.get(payload, :query)

        if is_binary(query) and String.contains?(query, "query Transcripts(") do
          %Tesla.Env{
            status: 200,
            body: %{
              "data" => %{
                "transcripts" => [
                  %{
                    "id" => "t-1",
                    "title" => "Weekly Sync — Team",
                    "date" => DateTime.to_iso8601(now),
                    "participants" => ["a@example.com"],
                    "meeting_link" => "https://meet.google.com/abc",
                    "summary" => %{
                      "overview" => "Match by link",
                      "action_items" => ["1", "2"],
                      "bullet_gist" => nil
                    }
                  },
                  %{
                    "id" => "t-2",
                    "title" => "Something else",
                    "date" => DateTime.to_iso8601(DateTime.add(now, 7200, :second)),
                    "participants" => [],
                    "meeting_link" => "https://meet.google.com/xyz",
                    "summary" => %{"overview" => "Nope", "action_items" => []}
                  }
                ]
              }
            }
          }
        else
          flunk("unexpected request: #{inspect(payload)}")
        end
    end)

    assert {:ok, %{accomplished: "Match by link", action_items: ["1", "2"], transcript_id: "t-1"}} =
             Fireflies.fetch_notes_for_event(ev)
  end

  test "fetch_notes_for_event falls back to nearest time within threshold" do
    now = ~U[2025-12-11 10:00:00Z]

    ev = %{
      id: "evt-time",
      starts_at: now,
      ends_at: DateTime.add(now, 3600, :second),
      title: "Daily Standup"
    }

    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.fireflies.ai/graphql", body: body} ->
        payload = if is_binary(body), do: Jason.decode!(body), else: body
        query = Map.get(payload, "query") || Map.get(payload, :query)

        if is_binary(query) and String.contains?(query, "query Transcripts(") do
          %Tesla.Env{
            status: 200,
            body: %{
              "data" => %{
                "transcripts" => [
                  %{
                    "id" => "t-near",
                    "title" => "Daily Standup",
                    "date" => DateTime.to_iso8601(DateTime.add(now, 600, :second)),
                    "summary" => %{"overview" => "Near", "action_items" => []}
                  },
                  %{
                    "id" => "t-far",
                    "title" => "Daily Standup",
                    "date" => DateTime.to_iso8601(DateTime.add(now, 10_800, :second)),
                    "summary" => %{"overview" => "Far", "action_items" => []}
                  }
                ]
              }
            }
          }
        else
          flunk("unexpected request: #{inspect(payload)}")
        end
    end)

    assert {:ok, %{accomplished: "Near", transcript_id: "t-near"}} =
             Fireflies.fetch_notes_for_event(ev)
  end

  test "fetch_notes_for_event returns :not_found when no suitable transcript" do
    now = ~U[2025-12-11 10:00:00Z]

    ev = %{
      id: "evt-none",
      starts_at: now,
      ends_at: DateTime.add(now, 3600, :second),
      title: "Weekly"
    }

    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.fireflies.ai/graphql", body: body} ->
        payload = if is_binary(body), do: Jason.decode!(body), else: body
        query = Map.get(payload, "query") || Map.get(payload, :query)

        if is_binary(query) and String.contains?(query, "query Transcripts(") do
          %Tesla.Env{
            status: 200,
            body: %{
              "data" => %{
                "transcripts" => [
                  %{
                    "id" => "t-too-far",
                    "date" => DateTime.to_iso8601(DateTime.add(now, 9_000, :second)),
                    "summary" => %{"overview" => "far"}
                  }
                ]
              }
            }
          }
        else
          flunk("unexpected request: #{inspect(payload)}")
        end
    end)

    assert :not_found == Fireflies.fetch_notes_for_event(ev)
  end

  test "fetch_notes_for_events maps multiple events from single query" do
    base = ~U[2025-12-11 12:00:00Z]
    ev1 = %{id: "evt-1", starts_at: base, ends_at: DateTime.add(base, 3600, :second), title: "A"}

    ev2 = %{
      id: "evt-2",
      starts_at: DateTime.add(base, 7200, :second),
      ends_at: DateTime.add(base, 10800, :second),
      title: "B"
    }

    Tesla.Mock.mock(fn
      %{method: :post, url: "https://api.fireflies.ai/graphql", body: body} ->
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
                    "summary" => %{"overview" => "A-notes", "action_items" => ["x"]}
                  },
                  %{
                    "id" => "t-b",
                    "title" => "B",
                    "date" => DateTime.to_iso8601(DateTime.add(base, 7200, :second)),
                    "summary" => %{"overview" => "B-notes", "action_items" => ["y"]}
                  }
                ]
              }
            }
          }
        else
          flunk("unexpected request: #{inspect(payload)}")
        end
    end)

    assert {:ok,
            %{
              "evt-1" => %{accomplished: "A-notes", action_items: ["x"], transcript_id: "t-a"},
              "evt-2" => %{accomplished: "B-notes", action_items: ["y"], transcript_id: "t-b"}
            }} =
             Fireflies.fetch_notes_for_events([ev1, ev2])
  end

  test "accepts numeric epoch date (ms) in transcripts" do
    now = ~U[2025-12-11 10:00:00Z]

    ev = %{
      id: "evt-ms",
      starts_at: now,
      ends_at: DateTime.add(now, 3600, :second),
      title: "Standup"
    }

    Tesla.Mock.mock(fn %{method: :post, url: "https://api.fireflies.ai/graphql", body: body} ->
      payload = if is_binary(body), do: Jason.decode!(body), else: body
      query = Map.get(payload, "query") || Map.get(payload, :query)

      if is_binary(query) and String.contains?(query, "query Transcripts(") do
        %Tesla.Env{
          status: 200,
          body: %{
            "data" => %{
              "transcripts" => [
                %{
                  "id" => "t-ms",
                  "title" => "Standup",
                  # epoch milliseconds
                  "date" => DateTime.to_unix(now, :millisecond),
                  "summary" => %{"overview" => "MS date", "action_items" => []}
                }
              ]
            }
          }
        }
      else
        flunk("unexpected request: #{inspect(payload)}")
      end
    end)

    assert {:ok, %{accomplished: "MS date", transcript_id: "t-ms"}} =
             Fireflies.fetch_notes_for_event(ev)
  end
end
