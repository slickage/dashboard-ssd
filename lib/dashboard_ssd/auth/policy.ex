defmodule DashboardSSD.Auth.Policy do
  @moduledoc """
  Simple RBAC policy checks.
  """
  alias DashboardSSD.Accounts.User

  @doc """
  Checks if a user is authorized to perform an action on a subject.

  ## Parameters
    - user: The user struct (can be nil for unauthenticated users)
    - action: The action to check (:read, :write, etc.)
    - subject: The subject/resource (:projects, :kb, etc.)

  ## Role Permissions
    - admin: Can perform any action on any subject
    - employee: Can read projects and knowledge base
    - client: Can read projects and knowledge base
    - others: No permissions
  """
  @spec can?(User.t() | nil, atom, atom) :: boolean
  def can?(%User{role: %{name: "admin"}}, _action, _subject), do: true

  def can?(%User{role: %{name: "employee"}}, action, subject) do
    action in [:read] and subject in [:projects, :kb]
  end

  def can?(%User{role: %{name: "client"}}, action, subject) do
    action in [:read] and subject in [:projects, :kb]
  end

  def can?(_user, _action, _subject), do: false
end
