defmodule DashboardSSD.Accounts.LinearUserLink do
  @moduledoc """
  Associates a DashboardSSD user with a Linear user record so we can bridge
  project assignments, metrics, and permissions between systems.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias DashboardSSD.Accounts.User

  @type t :: %__MODULE__{
          id: integer() | nil,
          user_id: integer() | nil,
          linear_user_id: String.t() | nil,
          linear_email: String.t() | nil,
          linear_name: String.t() | nil,
          linear_display_name: String.t() | nil,
          linear_avatar_url: String.t() | nil,
          auto_linked: boolean(),
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "linear_user_links" do
    belongs_to :user, User

    field :linear_user_id, :string
    field :linear_email, :string
    field :linear_name, :string
    field :linear_display_name, :string
    field :linear_avatar_url, :string
    field :auto_linked, :boolean, default: true

    timestamps(type: :utc_datetime)
  end

  @doc false
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(link, attrs) do
    link
    |> cast(attrs, [
      :user_id,
      :linear_user_id,
      :linear_email,
      :linear_name,
      :linear_display_name,
      :linear_avatar_url,
      :auto_linked
    ])
    |> validate_required([:user_id, :linear_user_id])
    |> unique_constraint(:user_id)
    |> unique_constraint(:linear_user_id)
  end
end
