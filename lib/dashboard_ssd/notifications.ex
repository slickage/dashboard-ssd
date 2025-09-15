defmodule DashboardSSD.Notifications do
  @moduledoc """
  Notifications context: alerts and notification rules.
  """
  import Ecto.Query, warn: false
  alias DashboardSSD.Notifications.{Alert, NotificationRule}
  alias DashboardSSD.Repo

  # Alerts
  @doc "List alerts"
  @spec list_alerts() :: [Alert.t()]
  def list_alerts, do: Repo.all(Alert)

  @doc "List alerts by project id"
  @spec list_alerts_by_project(pos_integer()) :: [Alert.t()]
  def list_alerts_by_project(project_id),
    do: from(a in Alert, where: a.project_id == ^project_id) |> Repo.all()

  @doc "Get alert by id"
  @spec get_alert!(pos_integer()) :: Alert.t()
  def get_alert!(id), do: Repo.get!(Alert, id)

  @doc "Change alert"
  @spec change_alert(Alert.t(), map()) :: Ecto.Changeset.t()
  def change_alert(%Alert{} = alert, attrs \\ %{}), do: Alert.changeset(alert, attrs)

  @doc "Create alert"
  @spec create_alert(map()) :: {:ok, Alert.t()} | {:error, Ecto.Changeset.t()}
  def create_alert(attrs), do: %Alert{} |> Alert.changeset(attrs) |> Repo.insert()

  @doc "Update alert"
  @spec update_alert(Alert.t(), map()) :: {:ok, Alert.t()} | {:error, Ecto.Changeset.t()}
  def update_alert(%Alert{} = alert, attrs), do: alert |> Alert.changeset(attrs) |> Repo.update()

  @doc "Delete alert"
  @spec delete_alert(Alert.t()) :: {:ok, Alert.t()} | {:error, Ecto.Changeset.t()}
  def delete_alert(%Alert{} = alert), do: Repo.delete(alert)

  # Notification Rules
  @doc "List notification rules"
  @spec list_notification_rules() :: [NotificationRule.t()]
  def list_notification_rules, do: Repo.all(NotificationRule)

  @doc "List notification rules by project id"
  @spec list_notification_rules_by_project(pos_integer()) :: [NotificationRule.t()]
  def list_notification_rules_by_project(project_id),
    do: from(n in NotificationRule, where: n.project_id == ^project_id) |> Repo.all()

  @doc "Get notification rule by id"
  @spec get_notification_rule!(pos_integer()) :: NotificationRule.t()
  def get_notification_rule!(id), do: Repo.get!(NotificationRule, id)

  @doc "Change notification rule"
  @spec change_notification_rule(NotificationRule.t(), map()) :: Ecto.Changeset.t()
  def change_notification_rule(%NotificationRule{} = rule, attrs \\ %{}),
    do: NotificationRule.changeset(rule, attrs)

  @doc "Create notification rule"
  @spec create_notification_rule(map()) ::
          {:ok, NotificationRule.t()} | {:error, Ecto.Changeset.t()}
  def create_notification_rule(attrs),
    do: %NotificationRule{} |> NotificationRule.changeset(attrs) |> Repo.insert()

  @doc "Update notification rule"
  @spec update_notification_rule(NotificationRule.t(), map()) ::
          {:ok, NotificationRule.t()} | {:error, Ecto.Changeset.t()}
  def update_notification_rule(%NotificationRule{} = rule, attrs),
    do: rule |> NotificationRule.changeset(attrs) |> Repo.update()

  @doc "Delete notification rule"
  @spec delete_notification_rule(NotificationRule.t()) ::
          {:ok, NotificationRule.t()} | {:error, Ecto.Changeset.t()}
  def delete_notification_rule(%NotificationRule{} = rule), do: Repo.delete(rule)
end
