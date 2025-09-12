defmodule DashboardSSD.Auth.Policy do
  @moduledoc """
  Simple RBAC policy checks.
  """
  alias DashboardSSD.Accounts.User

  @spec can?(User.t() | nil, atom, atom) :: boolean
  def can?(%User{role: %{name: "admin"}}, _action, _subject), do: true

  def can?(%User{role: %{name: "employee"}}, action, subject) do
    action in [:read] and subject in [:projects, :clients, :kb]
  end

  def can?(%User{role: %{name: "client"}}, action, subject) do
    action in [:read] and subject in [:projects, :kb]
  end

  def can?(_user, _action, _subject), do: false
end
