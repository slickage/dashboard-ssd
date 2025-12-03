defmodule DashboardSSD.Vault do
  @moduledoc """
  Cloak vault used to encrypt/decrypt sensitive fields at rest.

    - Reads keys from `config/runtime.exs` so credentials stay out of source control.
  - Applies deterministic encryption where schemas opt in via the Cloak Ecto helpers.
  - Supervised automatically to ensure crypto configuration is ready before Repo usage.
  """
  use Cloak.Vault, otp_app: :dashboard_ssd
end
