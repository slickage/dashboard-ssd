defmodule DashboardSSD.NotificationsTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.{Clients, Notifications, Projects}

  test "alerts and rules CRUD and list by project" do
    {:ok, c} = Clients.create_client(%{name: "Acme"})
    {:ok, p} = Projects.create_project(%{name: "Site", client_id: c.id})

    # Alerts
    {:ok, a} = Notifications.create_alert(%{project_id: p.id, message: "Down", status: "open"})
    # list all alerts covers list_alerts/0
    assert Enum.any?(Notifications.list_alerts(), &(&1.id == a.id))
    assert Notifications.get_alert!(a.id).message == "Down"
    {:ok, a2} = Notifications.update_alert(a, %{status: "closed"})
    assert a2.status == "closed"
    assert Enum.any?(Notifications.list_alerts_by_project(p.id), &(&1.id == a.id))
    # change_alert/2 returns a changeset
    assert %Ecto.Changeset{} = Notifications.change_alert(a)
    {:ok, _} = Notifications.delete_alert(a2)
    refute Enum.any?(Notifications.list_alerts_by_project(p.id), &(&1.id == a.id))

    # Rules
    {:ok, r} =
      Notifications.create_notification_rule(%{
        project_id: p.id,
        event_type: "deploy.failed",
        channel: "slack"
      })

    # list all rules covers list_notification_rules/0
    assert Enum.any?(Notifications.list_notification_rules(), &(&1.id == r.id))

    assert Notifications.get_notification_rule!(r.id).event_type == "deploy.failed"
    # change_notification_rule/2 returns a changeset
    assert %Ecto.Changeset{} = Notifications.change_notification_rule(r)
    {:ok, r2} = Notifications.update_notification_rule(r, %{channel: "email"})
    assert r2.channel == "email"
    assert Enum.any?(Notifications.list_notification_rules_by_project(p.id), &(&1.id == r.id))
    {:ok, _} = Notifications.delete_notification_rule(r2)
    refute Enum.any?(Notifications.list_notification_rules_by_project(p.id), &(&1.id == r.id))
  end
end
