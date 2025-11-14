defmodule DashboardSSD.Clients.Client do
  @moduledoc """
  Ecto schema for clients (customers) associated with projects.

    - Stores client metadata (name, slug) linked to projects/users.
  - Validates uniqueness of client names through its changeset.
  - Serves as the primary association for scoping client data in contexts.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t() | nil
        }

  @derive {Jason.Encoder, only: [:id, :name]}
  schema "clients" do
    field :name, :string
    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates a changeset for client validation and casting.

  ## Parameters
    - client: The client struct or changeset
    - attrs: Map of attributes to cast and validate

  ## Validations
    - name: Required
  """
  @spec changeset(t() | Changeset.t(), map()) :: Changeset.t()
  def changeset(client, attrs) do
    client
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
