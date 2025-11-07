defmodule DashboardSSD.Integrations.GoogleTokenTest do
  use DashboardSSD.DataCase, async: false

  alias DashboardSSD.Accounts.{ExternalIdentity, User}
  alias DashboardSSD.Integrations.GoogleToken
  alias DashboardSSD.Repo

  setup do
    # Ensure Tesla uses the mock adapter for token refresh
    Application.put_env(:tesla, :adapter, Tesla.Mock)

    # Provide client creds
    prev = {System.get_env("GOOGLE_CLIENT_ID"), System.get_env("GOOGLE_CLIENT_SECRET")}
    System.put_env("GOOGLE_CLIENT_ID", "cid")
    System.put_env("GOOGLE_CLIENT_SECRET", "csecret")

    on_exit(fn ->
      case prev do
        {nil, nil} ->
          System.delete_env("GOOGLE_CLIENT_ID")
          System.delete_env("GOOGLE_CLIENT_SECRET")

        {cid, csec} ->
          System.put_env("GOOGLE_CLIENT_ID", cid || "")
          System.put_env("GOOGLE_CLIENT_SECRET", csec || "")
      end
    end)

    :ok
  end

  test "returns existing token when not expired" do
    user = Repo.insert!(%User{name: "A", email: "a@example.com"})
    future = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.add(3600, :second)

    Repo.insert!(%ExternalIdentity{
      user_id: user.id,
      provider: "google",
      token: "tok",
      expires_at: future
    })

    assert {:ok, "tok"} = GoogleToken.get_access_token_for_user(user.id)
  end

  test "refreshes expired token with refresh_token" do
    user = Repo.insert!(%User{name: "B", email: "b@example.com"})
    past = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.add(-60, :second)

    idn =
      Repo.insert!(%ExternalIdentity{
        user_id: user.id,
        provider: "google",
        token: "old",
        refresh_token: "r1",
        expires_at: past
      })

    Tesla.Mock.mock(fn
      %{method: :post, url: "https://oauth2.googleapis.com/token", body: _body} ->
        # Body is form-encoded; accept either map or iolist
        # Return a new access token
        %Tesla.Env{status: 200, body: %{"access_token" => "newtok", "expires_in" => 1800}}
    end)

    assert {:ok, "newtok"} = GoogleToken.get_access_token_for_user(user.id)
    updated = Repo.get!(ExternalIdentity, idn.id)
    assert updated.token == "newtok"
    assert DateTime.compare(updated.expires_at, DateTime.utc_now()) == :gt
  end
end
