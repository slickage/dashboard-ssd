defmodule DashboardSSD.Mailer do
  @moduledoc """
  Thin wrapper around `Swoosh.Mailer` providing a single delivery pipeline.

    - Configured via `:dashboard_ssd, DashboardSSD.Mailer` environment settings.
  - Used by invite and notification modules to send transactional emails.
  - Keeps mailer supervision alongside the main OTP application for reuse in tests.
  """
  use Swoosh.Mailer, otp_app: :dashboard_ssd
end
