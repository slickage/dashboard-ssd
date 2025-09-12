defmodule DashboardSSD.Encrypted.Binary do
  # Encrypted Ecto type backed by :binary (bytea) in the DB
  use Cloak.Ecto.Binary, vault: DashboardSSD.Vault
end
