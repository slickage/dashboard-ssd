defmodule DashboardSSD.NotificationsTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Clients
  alias DashboardSSD.Notifications
  alias DashboardSSD.Projects

  setup do
    {:ok, client} = Clients.create_client(%{name: "C"})
    {:ok, project} = Projects.create_project(%{name: "P", client_id: client.id})
    %{project: project}
  end

  describe "alerts" do
    test "CRUD and by-project", %{project: project} do
      assert {:error, cs} = Notifications.create_alert(%{})

      assert %{
               project_id: ["can't be blank"],
               message: ["can't be blank"],
               status: ["can't be blank"]
             } = errors_on(cs)

      {:ok, alert} =
        Notifications.create_alert(%{project_id: project.id, message: "down", status: "open"})

      assert Enum.any?(Notifications.list_alerts(), &(&1.id == alert.id))
      assert Notifications.get_alert!(alert.id).message == "down"

      {:ok, alert} = Notifications.update_alert(alert, %{status: "closed"})
      assert alert.status == "closed"
      assert {:error, cs} = Notifications.update_alert(alert, %{status: nil})
      assert %{status: ["can't be blank"]} = errors_on(cs)

      ids = Notifications.list_alerts_by_project(project.id) |> Enum.map(& &1.id)
      assert ids == [alert.id]

      assert {:ok, _} = Notifications.delete_alert(alert)
    end

    test "change_alert returns a changeset", %{project: project} do
      {:ok, alert} =
        Notifications.create_alert(%{project_id: project.id, message: "down", status: "open"})

      changeset = Notifications.change_alert(alert, %{status: "closed"})
      assert changeset.valid?
      assert changeset.changes.status == "closed"
    end
  end

  describe "notification rules" do
    test "CRUD and by-project", %{project: project} do
      assert {:error, cs} = Notifications.create_notification_rule(%{})

      assert %{
               project_id: ["can't be blank"],
               event_type: ["can't be blank"],
               channel: ["can't be blank"]
             } = errors_on(cs)

      {:ok, rule} =
        Notifications.create_notification_rule(%{
          project_id: project.id,
          event_type: "deploy_failed",
          channel: "slack"
        })

      assert Enum.any?(Notifications.list_notification_rules(), &(&1.id == rule.id))
      assert Notifications.get_notification_rule!(rule.id).event_type == "deploy_failed"

      {:ok, rule} = Notifications.update_notification_rule(rule, %{channel: "email"})
      assert rule.channel == "email"
      assert {:error, cs} = Notifications.update_notification_rule(rule, %{channel: nil})
      assert %{channel: ["can't be blank"]} = errors_on(cs)

      ids = Notifications.list_notification_rules_by_project(project.id) |> Enum.map(& &1.id)
      assert ids == [rule.id]

      assert {:ok, _} = Notifications.delete_notification_rule(rule)
    end

    test "change_notification_rule returns a changeset", %{project: project} do
      {:ok, rule} =
        Notifications.create_notification_rule(%{
          project_id: project.id,
          event_type: "deploy_failed",
          channel: "slack"
        })

      changeset = Notifications.change_notification_rule(rule, %{channel: "email"})
      assert changeset.valid?
      assert changeset.changes.channel == "email"
    end
  end
end
