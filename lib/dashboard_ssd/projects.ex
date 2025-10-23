defmodule DashboardSSD.Projects do
  @moduledoc """
  Projects context: manage projects and queries per client.
  """
  import Ecto.Query, warn: false
  alias DashboardSSD.Clients
  alias DashboardSSD.Integrations
  alias DashboardSSD.Projects.{LinearWorkflowState, Project}
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
  @teams_page_size 50
  @projects_page_size 100

  @teams_query """
  query TeamsPage($first:Int!, $after:String) {
    teams(first: $first, after: $after) {
      nodes { id name }
      pageInfo { hasNextPage endCursor }
    }
  }
  """

  @team_projects_query """
  query TeamProjects($teamId: String!, $first:Int!, $after:String) {
    team(id: $teamId) {
      id
      name
      projects(first: $first, after: $after) {
        nodes { id name }
        pageInfo { hasNextPage endCursor }
      }
      states {
        nodes { id name type color }
      }
    }
  }
  """

  @spec sync_from_linear() :: {:ok, map()} | {:error, term()}
  def sync_from_linear do
    with {:ok, teams} <- fetch_linear_teams(),
         {:ok, teams_with_projects} <- fetch_projects_for_teams(teams) do
      {:ok, upsert_from_linear_nodes(teams_with_projects)}
    end
  end

  defp fetch_linear_teams(acc \\ [], cursor \\ nil) do
    variables =
      %{"first" => @teams_page_size}
      |> maybe_put_after(cursor)

    case Integrations.linear_graphql(@teams_query, variables) do
      {:ok,
       %{
         "data" => %{
           "teams" => %{
             "nodes" => nodes,
             "pageInfo" => %{"hasNextPage" => true, "endCursor" => end_cursor}
           }
         }
       }} ->
        fetch_linear_teams(acc ++ nodes, end_cursor)

      {:ok,
       %{
         "data" => %{
           "teams" => %{
             "nodes" => nodes,
             "pageInfo" => %{"hasNextPage" => false}
           }
         }
       }} ->
        {:ok, acc ++ nodes}

      {:ok, other} ->
        {:error, {:unexpected, other}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_projects_for_teams(teams) do
    Enum.reduce_while(teams, {:ok, []}, fn team, {:ok, acc} ->
      case fetch_team_projects(team) do
        {:ok, %{projects: projects, workflow_states: states}} ->
          sync_workflow_states(team["id"], states)

          team_name = team["name"]

          entry = %{
            "name" => team_name,
            "id" => team["id"],
            "projects" => projects,
            "linear_team_name" => team_name
          }

          {:cont, {:ok, [entry | acc]}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, entries} -> {:ok, Enum.reverse(entries)}
      other -> other
    end
  end

  defp fetch_team_projects(team, acc \\ %{projects: [], states: nil}, cursor \\ nil) do
    team_id = team["id"]

    variables =
      %{"teamId" => team_id, "first" => @projects_page_size}
      |> maybe_put_after(cursor)

    with {:ok, %{"data" => %{"team" => team_data}}} <-
           Integrations.linear_graphql(@team_projects_query, variables),
         {:cont, next_acc, next_cursor} <- handle_team_projects_page(team_data, acc) do
      fetch_team_projects(team, next_acc, next_cursor)
    else
      {:halt, final_acc} ->
        {:ok,
         %{
           projects: final_acc.projects,
           workflow_states: final_acc.states || []
         }}

      {:error, reason} ->
        {:error, reason}

      {:ok, other} ->
        {:error, {:unexpected, other}}
    end
  end

  defp maybe_put_after(vars, nil), do: vars
  defp maybe_put_after(vars, cursor), do: Map.put(vars, "after", cursor)

  defp handle_team_projects_page(nil, acc), do: {:halt, acc}

  defp handle_team_projects_page(team_data, acc) do
    projects = get_in(team_data, ["projects", "nodes"]) || []
    page_info = get_in(team_data, ["projects", "pageInfo"]) || %{}
    workflow_states = get_in(team_data, ["states", "nodes"]) || []

    next_acc =
      acc
      |> Map.update!(:projects, &(&1 ++ projects))
      |> Map.update(:states, workflow_states, fn existing -> existing || workflow_states end)

    if Map.get(page_info, "hasNextPage") do
      {:cont, next_acc, Map.get(page_info, "endCursor")}
    else
      {:halt, next_acc}
    end
  end

  defp upsert_from_linear_nodes(teams) do
    clients = Clients.list_clients()

    Enum.reduce(teams, %{inserted: 0, updated: 0}, fn team, acc ->
      process_team_projects(team, clients, acc)
    end)
  end

  defp process_team_projects(team, clients, acc) do
    team_name = team["linear_team_name"] || team["name"]
    team_id = team["id"]

    Enum.reduce(team["projects"] || [], acc, fn project_node, inner_acc ->
      name = project_node["name"]
      linear_project_id = project_node["id"]
      client_id = infer_client_id(name, team_name, clients)

      case upsert_project(linear_project_id, team_id, team_name, client_id, name) do
        {:inserted, _} -> %{inner_acc | inserted: inner_acc.inserted + 1}
        {:updated, _} -> %{inner_acc | updated: inner_acc.updated + 1}
        {:noop, _} -> inner_acc
      end
    end)
  end

  defp upsert_project(linear_project_id, linear_team_id, linear_team_name, client_id, name) do
    attrs =
      %{
        name: name,
        linear_project_id: linear_project_id,
        linear_team_id: linear_team_id,
        linear_team_name: linear_team_name
      }
      |> maybe_put_client(client_id)

    case find_existing_project(linear_project_id, name) do
      {:ok, project} -> update_project_fields(project, attrs)
      :error -> insert_new_project(attrs)
    end
  end

  defp find_existing_project(linear_project_id, name) when is_binary(linear_project_id) do
    case Repo.get_by(Project, linear_project_id: linear_project_id) do
      %Project{} = project -> {:ok, project}
      nil -> find_existing_project(nil, name)
    end
  end

  defp find_existing_project(_linear_project_id, name) do
    case Repo.get_by(Project, name: name) do
      %Project{} = project -> {:ok, project}
      nil -> :error
    end
  end

  defp update_project_fields(%Project{} = project, attrs) do
    updates = Enum.reduce(attrs, %{}, &collect_project_update(project, &1, &2))

    if updates == %{} do
      {:noop, project}
    else
      case update_project(project, updates) do
        {:ok, updated} -> {:updated, updated}
        {:error, _} -> {:noop, project}
      end
    end
  end

  defp collect_project_update(_project, {_key, nil}, acc), do: acc

  defp collect_project_update(project, {:client_id, value}, acc) do
    cond do
      is_nil(project.client_id) and project.client_id != value -> Map.put(acc, :client_id, value)
      is_nil(project.client_id) and project.client_id == value -> acc
      true -> acc
    end
  end

  defp collect_project_update(project, {key, value}, acc)
       when key in [:linear_project_id, :linear_team_id, :linear_team_name] do
    if Map.get(project, key) == value do
      acc
    else
      Map.put(acc, key, value)
    end
  end

  defp collect_project_update(project, {key, value}, acc) do
    if Map.get(project, key) == value do
      acc
    else
      Map.put(acc, key, value)
    end
  end

  defp insert_new_project(attrs) do
    case create_project(attrs) do
      {:ok, p} -> {:inserted, p}
      {:error, _} -> {:noop, nil}
    end
  end

  defp maybe_put_client(attrs, nil), do: attrs
  defp maybe_put_client(attrs, client_id), do: Map.put(attrs, :client_id, client_id)

  defp sync_workflow_states(_team_id, nil), do: :ok

  defp sync_workflow_states(team_id, states) when is_list(states) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    entries =
      Enum.map(states, fn state ->
        %{
          id: Ecto.UUID.generate(),
          linear_team_id: team_id,
          linear_state_id: state["id"],
          name: state["name"],
          type: Map.get(state, "type"),
          color: Map.get(state, "color"),
          inserted_at: now,
          updated_at: now
        }
      end)
      |> Enum.reject(&is_nil(&1.linear_state_id))

    if entries != [] do
      Repo.insert_all(LinearWorkflowState, entries,
        conflict_target: :linear_state_id,
        on_conflict: {:replace, [:linear_team_id, :name, :type, :color, :updated_at]}
      )
    end

    :ok
  end

  @doc """
  Returns a map of workflow state metadata for the given Linear team.
  """
  @spec workflow_state_metadata(String.t() | nil) :: map()
  def workflow_state_metadata(nil), do: %{}

  def workflow_state_metadata(team_id) do
    from(s in LinearWorkflowState, where: s.linear_team_id == ^team_id)
    |> Repo.all()
    |> Enum.reduce(%{}, fn state, acc ->
      Map.put(acc, state.linear_state_id, %{
        type: state.type,
        name: state.name,
        color: state.color
      })
    end)
  end

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
