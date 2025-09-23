defmodule DashboardSSD.Deployments.HealthCheckSetting do
  @moduledoc "Per-project configuration for production health checks (HTTP or AWS ELBv2)."
  use Ecto.Schema
  import Ecto.Changeset
  alias Ecto.Changeset

  @typedoc "Configuration for a project's production health check"
  @type t :: %__MODULE__{
          id: integer() | nil,
          project_id: integer() | nil,
          provider: String.t() | nil,
          endpoint_url: String.t() | nil,
          aws_region: String.t() | nil,
          aws_target_group_arn: String.t() | nil,
          enabled: boolean()
        }

  schema "health_check_settings" do
    belongs_to :project, DashboardSSD.Projects.Project, type: :id
    field :provider, :string
    field :endpoint_url, :string
    field :aws_region, :string
    field :aws_target_group_arn, :string
    field :enabled, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  @doc false
  @spec changeset(t() | Changeset.t(), map()) :: Changeset.t()
  def changeset(setting, attrs) do
    setting
    |> cast(attrs, [
      :project_id,
      :provider,
      :endpoint_url,
      :aws_region,
      :aws_target_group_arn,
      :enabled
    ])
    |> validate_inclusion(:provider, ["http", "aws_elbv2"],
      message: "must be http or aws_elbv2",
      allow_nil: true
    )
    |> validate_required_when_enabled()
    |> foreign_key_constraint(:project_id)
    |> unique_constraint(:project_id)
  end

  defp validate_required_when_enabled(changeset) do
    enabled = get_field(changeset, :enabled)
    provider = get_field(changeset, :provider)

    cond do
      enabled && provider == "http" ->
        validate_required(changeset, [:endpoint_url])

      enabled && provider == "aws_elbv2" ->
        validate_required(changeset, [:aws_region, :aws_target_group_arn])

      true ->
        changeset
    end
  end
end
