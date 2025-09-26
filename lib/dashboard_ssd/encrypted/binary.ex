defmodule DashboardSSD.Encrypted.Binary do
  @moduledoc "Encrypted Ecto type stored as a :binary (bytea) column."
  use Cloak.Ecto.Binary, vault: DashboardSSD.Vault
end
