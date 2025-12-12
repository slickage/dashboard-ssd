defmodule DashboardSSD.Integrations.GoogleCalendarCacheTest do
  use DashboardSSD.DataCase, async: false

  alias DashboardSSD.Accounts.{ExternalIdentity, User}
  alias DashboardSSD.Integrations
  alias DashboardSSD.Meetings.CacheStore
  alias DashboardSSD.Repo

  setup do
    # Ensure Tesla uses the mock adapter
    Application.put_env(:tesla, :adapter, Tesla.Mock)

    # Start and reset cache
    start_cache()
    CacheStore.reset()
    on_exit(fn -> CacheStore.reset() end)

    :ok
  end

  test "caches events for same window and user" do
    user = Repo.insert!(%User{name: "GC", email: "gc@example.com"})

    Repo.insert!(
      %ExternalIdentity{}
      |> ExternalIdentity.changeset(%{
        user_id: user.id,
        provider: "google",
        provider_id: "uid",
        token: "tok-user"
      })
    )

    # Counter agent to detect repeated HTTP calls
    {:ok, agent} = Agent.start_link(fn -> 0 end)

    Tesla.Mock.mock(fn
      %{method: :get, url: "https://www.googleapis.com/calendar/v3/calendars/primary/events"} ->
        count = Agent.get_and_update(agent, fn c -> {c + 1, c + 1} end)

        %Tesla.Env{
          status: 200,
          body: %{
            "items" => [
              %{
                "id" => "evt-#{count}",
                "summary" => "Cached Meeting",
                "start" => %{"dateTime" => "2025-11-04T09:00:00Z"},
                "end" => %{"dateTime" => "2025-11-04T10:00:00Z"}
              }
            ]
          }
        }
    end)

    now = ~U[2025-11-04 00:00:00Z]
    later = DateTime.add(now, 86_400, :second)

    assert {:ok, first} =
             Integrations.calendar_list_upcoming_for_user(user.id, now, later, ttl: 60_000)

    assert [%{id: id1}] = first

    # Second call should hit cache; mock would increment to evt-2 if invoked
    assert {:ok, second} =
             Integrations.calendar_list_upcoming_for_user(user.id, now, later, ttl: 60_000)

    assert [%{id: id2}] = second

    assert id1 == id2
    assert Agent.get(agent, & &1) == 1
  end

  defp start_cache do
    unless Process.whereis(DashboardSSD.Cache) do
      start_supervised!({DashboardSSD.Cache, []})
    end
  end
end
