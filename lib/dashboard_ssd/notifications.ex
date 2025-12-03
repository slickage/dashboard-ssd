defmodule DashboardSSD.Notifications do
  @moduledoc """
  Notifications context: alerts and notification rules.

    - Offers CRUD helpers for alerts and notification rules scoped to projects.
  - Serves as the single source of truth for alert/rule persistence logic.
  - Intended to integrate with outbound channels (email, Slack, etc.) managed elsewhere.
  """
  import Ecto.Query, warn: false
  alias DashboardSSD.Notifications.{Alert, NotificationRule}
  alias DashboardSSD.Repo

  # Alerts
  @doc """
  Lists all alerts ordered by insertion time.

  Returns a list of Alert structs.
  """
  @spec list_alerts() :: [Alert.t()]
  def list_alerts, do: Repo.all(Alert)

  @doc """
  Lists all alerts for a specific project.

  Returns alerts ordered by insertion time (most recent first).
  """
  @spec list_alerts_by_project(pos_integer()) :: [Alert.t()]
  def list_alerts_by_project(project_id),
    do: from(a in Alert, where: a.project_id == ^project_id) |> Repo.all()

  @doc """
  Fetches an alert by ID.

  Raises Ecto.NoResultsError if the alert does not exist.
  """
  @spec get_alert!(pos_integer()) :: Alert.t()
  def get_alert!(id), do: Repo.get!(Alert, id)

  @doc """
  Returns a changeset for tracking alert changes.

  Validates the given attributes against the alert schema.
  """
  @spec change_alert(Alert.t(), map()) :: Ecto.Changeset.t()
  def change_alert(%Alert{} = alert, attrs \\ %{}), do: Alert.changeset(alert, attrs)

  @doc """
  Creates a new alert with the given attributes.

  Returns {:ok, alert} on success or {:error, changeset} on validation failure.
  """
  @spec create_alert(map()) :: {:ok, Alert.t()} | {:error, Ecto.Changeset.t()}
  def create_alert(attrs), do: %Alert{} |> Alert.changeset(attrs) |> Repo.insert()

  @doc """
  Updates an existing alert with the given attributes.

  Returns {:ok, alert} on success or {:error, changeset} on validation failure.
  """
  @spec update_alert(Alert.t(), map()) :: {:ok, Alert.t()} | {:error, Ecto.Changeset.t()}
  def update_alert(%Alert{} = alert, attrs), do: alert |> Alert.changeset(attrs) |> Repo.update()

  @doc """
  Deletes an alert from the database.

  Returns {:ok, alert} on success or {:error, changeset} on constraint violation.
  """
  @spec delete_alert(Alert.t()) :: {:ok, Alert.t()} | {:error, Ecto.Changeset.t()}
  def delete_alert(%Alert{} = alert), do: Repo.delete(alert)

  # Notification Rules
  @doc """
  Lists all notification rules ordered by insertion time.

  Returns a list of NotificationRule structs.
  """
  @spec list_notification_rules() :: [NotificationRule.t()]
  def list_notification_rules, do: Repo.all(NotificationRule)

  @doc """
  Lists all notification rules for a specific project.

  Returns notification rules ordered by insertion time (most recent first).
  """
  @spec list_notification_rules_by_project(pos_integer()) :: [NotificationRule.t()]
  def list_notification_rules_by_project(project_id),
    do: from(n in NotificationRule, where: n.project_id == ^project_id) |> Repo.all()

  @doc """
  Fetches a notification rule by ID.

  Raises Ecto.NoResultsError if the notification rule does not exist.
  """
  @spec get_notification_rule!(pos_integer()) :: NotificationRule.t()
  def get_notification_rule!(id), do: Repo.get!(NotificationRule, id)

  @doc """
  Returns a changeset for tracking notification rule changes.

  Validates the given attributes against the notification rule schema.
  """
  @spec change_notification_rule(NotificationRule.t(), map()) :: Ecto.Changeset.t()
  def change_notification_rule(%NotificationRule{} = rule, attrs \\ %{}),
    do: NotificationRule.changeset(rule, attrs)

  @doc """
  Creates a new notification rule with the given attributes.

  Returns {:ok, notification_rule} on success or {:error, changeset} on validation failure.
  """
  @spec create_notification_rule(map()) ::
          {:ok, NotificationRule.t()} | {:error, Ecto.Changeset.t()}
  def create_notification_rule(attrs),
    do: %NotificationRule{} |> NotificationRule.changeset(attrs) |> Repo.insert()

  @doc """
  Updates an existing notification rule with the given attributes.

  Returns {:ok, notification_rule} on success or {:error, changeset} on validation failure.
  """
  @spec update_notification_rule(NotificationRule.t(), map()) ::
          {:ok, NotificationRule.t()} | {:error, Ecto.Changeset.t()}
  def update_notification_rule(%NotificationRule{} = rule, attrs),
    do: rule |> NotificationRule.changeset(attrs) |> Repo.update()

  @doc """
  Deletes a notification rule from the database.

  Returns {:ok, notification_rule} on success or {:error, changeset} on constraint violation.
  """
  @spec delete_notification_rule(NotificationRule.t()) ::
          {:ok, NotificationRule.t()} | {:error, Ecto.Changeset.t()}
  def delete_notification_rule(%NotificationRule{} = rule), do: Repo.delete(rule)
end
