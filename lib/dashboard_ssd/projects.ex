defmodule DashboardSSD.Projects do
  @moduledoc """
  Projects context: manage projects and queries per client.
  """
  import Ecto.Query, warn: false
  alias DashboardSSD.Clients
  alias DashboardSSD.Integrations
  alias DashboardSSD.Projects.Project
  alias DashboardSSD.Repo

  @doc """
  Lists all projects with their associated clients preloaded.

  Returns projects ordered by insertion time (most recent first).
  """
  @spec list_projects() :: [Project.t()]
  def list_projects do
    from(p in Project, preload: [:client]) |> Repo.all()
  end

  @doc """
  Lists all projects associated with a specific client.

  Returns projects for the given client_id with clients preloaded.
  """
  @spec list_projects_by_client(pos_integer()) :: [Project.t()]
  def list_projects_by_client(client_id) do
    from(p in Project, where: p.client_id == ^client_id, preload: [:client]) |> Repo.all()
  end

  @doc """
  Fetches a project by ID with client preloaded.

  Raises Ecto.NoResultsError if the project does not exist.
  """
  @spec get_project!(pos_integer()) :: Project.t()
  def get_project!(id), do: Repo.get!(Project, id) |> Repo.preload(:client)

  @doc """
  Returns a changeset for tracking project changes.

  Validates the given attributes against the project schema.
  """
  @spec change_project(Project.t(), map()) :: Ecto.Changeset.t()
  def change_project(%Project{} = project, attrs \\ %{}), do: Project.changeset(project, attrs)

  @doc """
  Creates a new project with the given attributes.

  Returns {:ok, project} on success or {:error, changeset} on validation failure.
  """
  @spec create_project(map()) :: {:ok, Project.t()} | {:error, Ecto.Changeset.t()}
  def create_project(attrs) do
    %Project{} |> Project.changeset(attrs) |> Repo.insert()
  end

  @doc """
  Updates an existing project with the given attributes.

  Returns {:ok, project} on success or {:error, changeset} on validation failure.
  """
  @spec update_project(Project.t(), map()) :: {:ok, Project.t()} | {:error, Ecto.Changeset.t()}
  def update_project(%Project{} = project, attrs) do
    project |> Project.changeset(attrs) |> Repo.update()
  end

  @doc """
  Deletes a project from the database.

  Returns {:ok, project} on success or {:error, changeset} on constraint violation.
  """
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
      %Project{} = p -> update_client_if_missing(p, client_id)
      nil -> insert_new_project(client_id, name)
    end
  end

  # Do not clear or overwrite an existing client assignment during sync.
  # Only fill in client_id when it is currently nil and a non-nil client_id is inferred.
  defp update_client_if_missing(%Project{} = p, client_id) do
    if is_nil(p.client_id) and not is_nil(client_id) do
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
