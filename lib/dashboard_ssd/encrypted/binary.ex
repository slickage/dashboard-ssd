defmodule DashboardSSD.Encrypted.Binary do
  @moduledoc """
  Encrypted Ecto type stored as a :binary (bytea) column.

    - Delegates encryption/decryption to `DashboardSSD.Vault`.
  - Provides a drop-in Ecto field type for schemas needing encrypted binaries.
  - Keeps implementation details encapsulated so schemas stay concise.
  """
  use Cloak.Ecto.Binary, vault: DashboardSSD.Vault
end
