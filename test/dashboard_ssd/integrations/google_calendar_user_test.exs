defmodule DashboardSSD.Integrations.GoogleCalendarUserTest do
  use DashboardSSD.DataCase

  alias DashboardSSD.Accounts.{ExternalIdentity, User}
  alias DashboardSSD.Integrations.GoogleCalendar
  alias DashboardSSD.Repo

  setup do
    # Ensure Tesla uses the mock adapter
    Application.put_env(:tesla, :adapter, Tesla.Mock)

    # Clear env fallback
    prev_env = System.get_env("GOOGLE_OAUTH_TOKEN")
    System.delete_env("GOOGLE_OAUTH_TOKEN")

    on_exit(fn ->
      if prev_env, do: System.put_env("GOOGLE_OAUTH_TOKEN", prev_env), else: System.delete_env("GOOGLE_OAUTH_TOKEN")
    end)

    :ok
  end

  test "uses user's stored google token when present" do
    user = Repo.insert!(%User{name: "GCal", email: "gcal@example.com"})

    Repo.insert!(
      %ExternalIdentity{}
      |> ExternalIdentity.changeset(%{user_id: user.id, provider: "google", provider_id: "uid", token: "tok-user"})
    )

    Tesla.Mock.mock(fn
      %{method: :get, url: "https://www.googleapis.com/calendar/v3/calendars/primary/events", headers: headers} ->
        assert Enum.any?(headers, fn {k, v} -> k == "authorization" and String.starts_with?(v, "Bearer ") end)
        %Tesla.Env{status: 200, body: %{"items" => []}}
    end)

    now = DateTime.utc_now()
    later = DateTime.add(now, 3600, :second)
    assert {:ok, []} = GoogleCalendar.list_upcoming_for_user(user.id, now, later)
  end

  # No env fallback: when user has no token and not in mock mode, return :no_token
  test "returns :no_token when user token missing and not mock" do
    user = Repo.insert!(%User{name: "GCal2", email: "gcal2@example.com"})
    now = DateTime.utc_now()
    later = DateTime.add(now, 3600, :second)
    assert {:error, :no_token} = GoogleCalendar.list_upcoming_for_user(user.id, now, later)
  end

  test "returns :no_token when no user/env token and not mock" do
    user = Repo.insert!(%User{name: "GCal3", email: "gcal3@example.com"})
    now = DateTime.utc_now()
    later = DateTime.add(now, 3600, :second)
    assert {:error, :no_token} = GoogleCalendar.list_upcoming_for_user(user.id, now, later)
  end
end
