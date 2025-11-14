defmodule DashboardSSD.Auth.Capabilities do
  @moduledoc """
  Canonical capability catalog used for RBAC decisions and admin configuration.

    - Defines the list of capability codes, labels, and descriptions shown in settings.
  - Provides default role assignments used for seeding and reset actions.
  - Exposes helper functions (`valid?/1`, `default_assignments/0`, etc.) for guards.
  """

  @capabilities [
    %{
      code: "dashboard.view",
      label: "Dashboard",
      group: :navigation,
      description: "View the overview dashboard."
    },
    %{
      code: "projects.view",
      label: "Projects (View)",
      group: :projects,
      description: "View project lists, details, and health."
    },
    %{
      code: "projects.manage",
      label: "Projects (Manage)",
      group: :projects,
      description: "Create, edit, and delete projects."
    },
    %{
      code: "clients.view",
      label: "Clients (View)",
      group: :clients,
      description: "Browse client records."
    },
    %{
      code: "clients.manage",
      label: "Clients (Manage)",
      group: :clients,
      description: "Create, edit, and delete client records."
    },
    %{
      code: "contracts.client.view",
      label: "Client Contracts",
      group: :contracts,
      description: "View the Contracts tab in the client portal."
    },
    %{
      code: "knowledge_base.view",
      label: "Knowledge Base (View)",
      group: :knowledge_base,
      description: "Search and read knowledge base documents."
    },
    %{
      code: "analytics.view",
      label: "Analytics (View)",
      group: :analytics,
      description: "Access analytics dashboards."
    },
    %{
      code: "settings.personal",
      label: "Personal Settings",
      group: :settings,
      description: "Modify personal preferences and integrations."
    },
    %{
      code: "settings.rbac",
      label: "RBAC Settings",
      group: :settings,
      description: "Manage role capability assignments."
    }
  ]

  @default_assignments %{
    "admin" => Enum.map(@capabilities, & &1.code),
    "employee" => [
      "dashboard.view",
      "projects.view",
      "clients.view",
      "knowledge_base.view",
      "settings.personal"
    ],
    "client" => [
      "projects.view",
      "clients.view",
      "settings.personal",
      "contracts.client.view"
    ]
  }

  @doc "Returns the capability catalog with metadata."
  @spec all() :: [map()]
  def all, do: @capabilities

  @doc "Returns just the capability codes."
  @spec codes() :: [String.t()]
  def codes, do: Enum.map(@capabilities, & &1.code)

  @doc "Returns the default capability assignments per role."
  @spec default_assignments() :: %{String.t() => [String.t()]}
  def default_assignments, do: @default_assignments

  @doc "Checks whether the given capability code exists in the catalog."
  @spec valid?(String.t()) :: boolean()
  def valid?(code), do: code in codes()

  @doc """
  Fetches capability metadata by code.

  Returns nil when the capability is not defined.
  """
  @spec get(String.t()) :: map() | nil
  def get(code), do: Enum.find(@capabilities, &(&1.code == code))
end
