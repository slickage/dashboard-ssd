defmodule DashboardSSD.Deployments.HealthCheckSetting do
  use Ecto.Schema
  import Ecto.Changeset

  @typedoc "Configuration for a project's production health check"
  @type t :: %__MODULE__{
          id: integer() | nil,
          project_id: integer(),
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
    |> foreign_key_constraint(:project_id)
    |> unique_constraint(:project_id)
  end
end
