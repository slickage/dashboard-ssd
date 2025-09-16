defmodule DashboardSSD.Vault do
  @moduledoc "Cloak vault used to encrypt/decrypt sensitive fields at rest."
  use Cloak.Vault, otp_app: :dashboard_ssd
end
