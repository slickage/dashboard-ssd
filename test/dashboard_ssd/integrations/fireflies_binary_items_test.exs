defmodule DashboardSSD.Integrations.FirefliesBinaryItemsTest do
  use DashboardSSD.DataCase, async: false

  alias DashboardSSD.Integrations.Fireflies
  alias DashboardSSD.Meetings.CacheStore

  setup do
    # Ensure token configured for the client
    prev = Application.get_env(:dashboard_ssd, :integrations)

    Application.put_env(
      :dashboard_ssd,
      :integrations,
      Keyword.merge(prev || [], fireflies_api_token: "tok")
    )

    CacheStore.reset()

    on_exit(fn ->
      if prev,
        do: Application.put_env(:dashboard_ssd, :integrations, prev),
        else: Application.delete_env(:dashboard_ssd, :integrations)

      CacheStore.reset()
    end)

    :ok
  end

  test "normalizes binary action_items into list" do
    series_id = "series-binary-items"

    Tesla.Mock.mock(fn
      # Bites lookup to map series -> transcript
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
                      "id" => "b-bin",
                      "transcript_id" => "t-bin",
                      "created_at" => "2024-01-01T00:00:00Z",
                      "created_from" => %{"id" => series_id, "name" => "Weekly"}
                    }
                  ]
                }
              }
            }

          # Transcript summary returns action_items as a single string
          is_binary(query) and String.contains?(query, "query Transcript(") and
              (Map.get(vars, "transcriptId") == "t-bin" or Map.get(vars, :transcriptId) == "t-bin") ->
            %Tesla.Env{
              status: 200,
              body: %{
                "data" => %{
                  "transcript" => %{
                    "summary" => %{
                      "overview" => "Some notes",
                      "action_items" => "A\nB\n",
                      "bullet_gist" => nil
                    }
                  }
                }
              }
            }

          true ->
            flunk("unexpected request: #{inspect(body)}")
        end
    end)

    assert {:ok, %{action_items: ["A", "B"]}} =
             Fireflies.fetch_latest_for_series(series_id, title: "Weekly")
  end
end
