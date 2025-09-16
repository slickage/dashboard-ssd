defmodule DashboardSSD.Projects do
  @moduledoc """
  Projects context: manage projects and queries per client.
  """
  import Ecto.Query, warn: false
  alias DashboardSSD.Clients
  alias DashboardSSD.Integrations
  alias DashboardSSD.Projects.Project
  alias DashboardSSD.Repo

  @doc "List all projects"
  @spec list_projects() :: [Project.t()]
  def list_projects do
    from(p in Project, preload: [:client]) |> Repo.all()
  end

  @doc "List projects for a given client id"
  @spec list_projects_by_client(pos_integer()) :: [Project.t()]
  def list_projects_by_client(client_id) do
    from(p in Project, where: p.client_id == ^client_id, preload: [:client]) |> Repo.all()
  end

  @doc "Fetch a project by id, raising if not found"
  @spec get_project!(pos_integer()) :: Project.t()
  def get_project!(id), do: Repo.get!(Project, id)

  @doc "Return a changeset for a project with proposed changes"
  @spec change_project(Project.t(), map()) :: Ecto.Changeset.t()
  def change_project(%Project{} = project, attrs \\ %{}), do: Project.changeset(project, attrs)

  @doc "Create a new project"
  @spec create_project(map()) :: {:ok, Project.t()} | {:error, Ecto.Changeset.t()}
  def create_project(attrs) do
    %Project{} |> Project.changeset(attrs) |> Repo.insert()
  end

  @doc "Update an existing project"
  @spec update_project(Project.t(), map()) :: {:ok, Project.t()} | {:error, Ecto.Changeset.t()}
  def update_project(%Project{} = project, attrs) do
    project |> Project.changeset(attrs) |> Repo.update()
  end

  @doc "Delete a project"
  @spec delete_project(Project.t()) :: {:ok, Project.t()} | {:error, Ecto.Changeset.t()}
  def delete_project(%Project{} = project) do
    Repo.delete(project)
  end

  @doc """
  Sync projects from Linear into local DB as references.

  Strategy (initial):
  - Fetch teams and their projects from Linear via GraphQL
  - Infer client by matching team/project name to existing client names (substring, case-insensitive)
    If no match, leave client_id nil
  - Upsert local projects by name and update client assignment when inferred
  Returns: {:ok, %{inserted: n, updated: m}}
  """
  @spec sync_from_linear() :: {:ok, map()} | {:error, term()}
  def sync_from_linear do
    query = """
    query TeamsWithProjects($first:Int!) {
      teams(first: $first) {
        nodes { id name projects(first: $first) { nodes { id name } } }
      }
    }
    """

    case Integrations.linear_graphql(query, %{"first" => 50}) do
      {:ok, %{"data" => %{"teams" => %{"nodes" => teams}}}} ->
        {:ok, upsert_from_linear_nodes(teams)}

      {:error, reason} ->
        {:error, reason}

      other ->
        {:error, {:unexpected, other}}
    end
  end

  defp upsert_from_linear_nodes(teams) do
    clients = Clients.list_clients()

    Enum.flat_map(teams, fn t ->
      team_name = t["name"]

      for p <- get_in(t, ["projects", "nodes"]) || [],
          do: %{name: p["name"], team_name: team_name}
    end)
    |> Enum.reduce(%{inserted: 0, updated: 0}, fn %{name: name, team_name: team_name}, acc ->
      client_id = infer_client_id(name, team_name, clients)

      case upsert_project_by_name(client_id, name) do
        {:inserted, _} -> %{acc | inserted: acc.inserted + 1}
        {:updated, _} -> %{acc | updated: acc.updated + 1}
        {:noop, _} -> acc
      end
    end)
  end

  defp upsert_project_by_name(client_id, name) do
    case Repo.get_by(Project, name: name) do
      %Project{} = p -> update_if_changed(p, client_id)
      nil -> insert_new_project(client_id, name)
    end
  end

  defp update_if_changed(%Project{} = p, client_id) do
    if p.client_id != client_id do
      case update_project(p, %{client_id: client_id}) do
        {:ok, p2} -> {:updated, p2}
        {:error, _} -> {:noop, p}
      end
    else
      {:noop, p}
    end
  end

  defp insert_new_project(client_id, name) do
    attrs = %{name: name} |> maybe_put_client(client_id)

    case create_project(attrs) do
      {:ok, p} -> {:inserted, p}
      {:error, _} -> {:noop, nil}
    end
  end

  defp maybe_put_client(attrs, nil), do: attrs
  defp maybe_put_client(attrs, client_id), do: Map.put(attrs, :client_id, client_id)

  defp infer_client_id(project_name, team_name, clients) do
    pname = String.downcase(project_name || "")
    tname = String.downcase(team_name || "")

    clients
    |> Enum.find(fn c ->
      cname = String.downcase(c.name || "")
      cname != "" and (String.contains?(pname, cname) or String.contains?(tname, cname))
    end)
    |> case do
      nil -> nil
      c -> c.id
    end
  end
end
