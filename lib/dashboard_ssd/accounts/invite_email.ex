defmodule DashboardSSD.Accounts.InviteEmail do
  @moduledoc "Email helpers for sending user invitations."
  import Swoosh.Email
  alias DashboardSSD.Accounts.UserInvite
  alias DashboardSSDWeb.Endpoint

  @spec new_invite_email(UserInvite.t()) :: Swoosh.Email.t()
  def new_invite_email(%UserInvite{} = invite) do
    url = invite_url(invite)
    invited_by = invite.invited_by && (invite.invited_by.name || invite.invited_by.email)
    client_name = invite.client && invite.client.name

    html_body = """
    <p>Hello,</p>
    <p>You have been invited#{invite_client_phrase(client_name)} to join DashboardSSD.</p>
    <p>Click the link below to sign in with Google and complete your access:</p>
    <p><a href="#{url}">Accept invitation</a></p>
    <p>If you did not expect this invitation, you can safely ignore this email.</p>
    <p>#{courtesy(invited_by)}</p>
    """

    text_body = """
    Hello,

    You have been invited#{invite_client_phrase(client_name)} to join DashboardSSD.

    Accept your invitation by signing in with Google:
    #{url}

    If you did not expect this invitation, you can ignore this email.

    #{courtesy(invited_by)}
    """

    new()
    |> to(invite.email)
    |> from({"DashboardSSD", from_address()})
    |> subject("You're invited to DashboardSSD")
    |> html_body(html_body)
    |> text_body(text_body)
  end

  defp invite_url(invite), do: Endpoint.url() <> "/invites/#{invite.token}"

  defp courtesy(nil), do: "Thanks,\nDashboardSSD Team"
  defp courtesy(name), do: "Thanks,\n#{name}"

  defp invite_client_phrase(nil), do: ""
  defp invite_client_phrase(name), do: " to collaborate on #{name}"

  defp from_address do
    Application.get_env(:dashboard_ssd, __MODULE__, [])
    |> Keyword.get(:from_email, "no-reply@dashboardssd.local")
  end
end
