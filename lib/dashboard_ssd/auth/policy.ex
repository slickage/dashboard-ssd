defmodule DashboardSSD.Auth.Policy do
  @moduledoc """
  Simple RBAC policy checks.
  """
  alias DashboardSSD.Accounts
  alias DashboardSSD.Accounts.User

  @doc """
  Checks if a user is authorized to perform an action on a subject.

  ## Parameters
    - user: The user struct (can be nil for unauthenticated users)
    - action: The action to check (:read, :write, etc.)
    - subject: The subject/resource (:projects, :kb, etc.)

  ## Role Permissions
    - admin: Honors stored capability assignments when a mapping exists, but retains
      a fallback allow for unmapped actions to prevent accidental lockouts.
    - other roles: Determined entirely by capability assignments stored in the database
  """
  @spec can?(User.t() | nil, atom, atom) :: boolean
  def can?(%User{role: %{name: "admin"}} = user, action, subject) do
    case capability_for(action, subject) do
      {:ok, requirement} -> has_capability?(user, requirement)
      :error -> true
    end
  end

  def can?(%User{} = user, action, subject) do
    case capability_for(action, subject) do
      {:ok, requirement} -> has_capability?(user, requirement)
      :error -> false
    end
  end

  def can?(_user, _action, _subject), do: false

  @capability_map %{
    {:read, :dashboard} => "dashboard.view",
    {:read, :projects} => "projects.view",
    {:write, :projects} => "projects.manage",
    {:manage, :projects} => "projects.manage",
    {:read, :clients} => "clients.view",
    {:write, :clients} => "clients.manage",
    {:manage, :clients} => "clients.manage",
    {:read, :knowledge_base} => "knowledge_base.view",
    {:read, :kb} => "knowledge_base.view",
    {:read, :analytics} => "analytics.view",
    {:read, :settings} => ["settings.personal", "settings.rbac"],
    {:manage, :rbac} => "settings.rbac",
    {:read, :rbac} => "settings.rbac"
  }

  defp capability_for(action, subject) do
    Map.fetch(@capability_map, {action, subject})
  end

  defp capabilities_for(%User{role: nil}), do: []

  defp capabilities_for(%User{role: %{id: role_id}}) do
    Accounts.capabilities_for_role(role_id)
  end

  defp capabilities_for(_), do: []

  defp has_capability?(user, requirement) when is_binary(requirement) do
    requirement in capabilities_for(user)
  end

  defp has_capability?(user, requirements) when is_list(requirements) do
    Enum.any?(requirements, &(&1 in capabilities_for(user)))
  end

  defp has_capability?(_user, _), do: false
end
