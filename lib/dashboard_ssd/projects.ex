defmodule DashboardSSD.Projects do
  @moduledoc """
  Projects context: manage projects and queries per client.
  """
  import Ecto.Query
  alias DashboardSSD.Clients
  alias DashboardSSD.Integrations
  alias DashboardSSD.Integrations.LinearUtils
  alias DashboardSSD.Projects.{CacheStore, LinearTeamMember, LinearWorkflowState, Project}
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

  @sync_cache_fresh_ttl_ms :timer.minutes(10)
  @sync_cache_backoff_ms :timer.minutes(5)
  @sync_cache_entry_ttl_ms :timer.hours(2)
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

  @team_projects_memberships_query """
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
      teamMemberships(first: 100) {
        nodes {
          user {
            id
            name
            displayName
            email
            avatarUrl
          }
        }
      }
    }
  }
  """

  @team_projects_members_query """
  query TeamProjectsWithMembers($teamId: String!, $first:Int!, $after:String) {
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
      members(first: 100) {
        nodes {
          id
          name
          displayName
          email
          avatarUrl
        }
      }
    }
  }
  """

  @team_projects_without_members_query """
  query TeamProjectsNoMembers($teamId: String!, $first:Int!, $after:String) {
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

  @team_project_queries [
    {@team_projects_memberships_query, :team_memberships},
    {@team_projects_members_query, :members},
    {@team_projects_without_members_query, :none}
  ]

  @doc """
  Sync projects from Linear into the local DB with caching.

  In `:test` environment (and only there) this function always performs the full
  sync and returns the same tuple as the previous implementation:

      {:ok, %{inserted: n, updated: m}} | {:error, reason}

  In other environments the function:

    * Serves cached data when the previous sync is still fresh
    * Respects a short backoff window after hitting Linear's rate limit
    * Returns cached data with metadata when fresh results are unavailable

  The returned tuples have the following shape in non-test envs:

      {:ok, %{inserted: n, updated: m}, %{cached: boolean(), synced_at: DateTime.t(), reason: atom() | nil, message: String.t() | nil}}

  Callers may pass `force: true` to bypass the freshness check (useful for
  manual "Sync now" actions). Backoff is still honoured unless the application
  environment is `:test`.
  """
  @spec sync_from_linear(keyword()) :: {:ok, map()} | {:error, term()}
  def sync_from_linear(opts \\ []) do
    env = Application.get_env(:dashboard_ssd, :env, runtime_env())

    force? = Keyword.get(opts, :force, false) == true

    case env do
      :test -> do_sync_from_linear()
      _ -> maybe_sync_with_cache(force?)
    end
  end

  @spec maybe_sync_with_cache(boolean()) :: {:ok, map()} | {:error, term()}
  defp maybe_sync_with_cache(force?) do
    now_mono = System.monotonic_time(:millisecond)
    now = DateTime.utc_now()
    cache_entry = current_cache_entry()

    fresh_result =
      if force? do
        :no
      else
        fresh_cache_decision(cache_entry, now_mono)
      end

    case fresh_result do
      {:ok, entry} ->
        serve_cached_entry(entry, :fresh_cache)

      :no ->
        case rate_limited_decision(cache_entry, now_mono) do
          {:ok, entry} -> serve_cached_entry(entry, :rate_limited)
          :no -> perform_remote_sync(cache_entry, now, now_mono)
        end
    end
  end

  @doc """
  Performs the Linear sync without any caching. Kept public for callers that
  specifically need the raw behaviour (e.g. tests).

  Returns: {:ok, %{inserted: n, updated: m}} | {:error, term()}
  """
  @spec raw_sync_from_linear() :: {:ok, map()} | {:error, term()}
  def raw_sync_from_linear do
    do_sync_from_linear()
  end

  @doc false
  defp do_sync_from_linear do
    with {:ok, teams} <- fetch_linear_teams(),
         {:ok, teams_with_projects} <- fetch_projects_for_teams(teams) do
      result = upsert_from_linear_nodes(teams_with_projects)
      summaries = generate_linear_summaries()

      {:ok, Map.put(result, :summaries, summaries)}
    end
  end

  defp generate_linear_summaries do
    projects = list_projects()

    env = Application.get_env(:dashboard_ssd, :env, runtime_env())

    summaries_enabled_in_test? =
      Application.get_env(:dashboard_ssd, :linear_summary_in_test?, false)

    cond do
      env == :test and not summaries_enabled_in_test? ->
        unavailable_summaries(projects)

      LinearUtils.linear_enabled?() ->
        build_linear_summaries(projects)

      true ->
        unavailable_summaries(projects)
    end
  end

  defp build_linear_summaries(projects) do
    state_metadata_map =
      projects
      |> Enum.map(& &1.linear_team_id)
      |> workflow_state_metadata_multi()

    Enum.reduce(projects, %{}, fn project, acc ->
      key = to_string(project.id)

      summary =
        LinearUtils.fetch_linear_summary(project,
          state_metadata: state_metadata_map
        )

      Map.put(acc, key, summary)
    end)
  end

  defp unavailable_summaries(projects) do
    Enum.reduce(projects, %{}, fn project, acc ->
      Map.put(acc, to_string(project.id), :unavailable)
    end)
  end

  defp ensure_counts(nil), do: %{inserted: 0, updated: 0, summaries: %{}}

  defp ensure_counts(payload) when is_map(payload) do
    payload
    |> Map.put_new(:inserted, 0)
    |> Map.put_new(:updated, 0)
    |> Map.update(:summaries, %{}, fn
      nil -> %{}
      summaries -> summaries
    end)
  end

  @spec maybe_use_cached_summaries(map(), map() | nil) :: map()
  defp maybe_use_cached_summaries(payload, cache_entry) do
    case summaries_from_payload(payload) || summaries_from_cache(cache_entry) do
      nil -> payload
      summaries -> Map.put(payload, :summaries, summaries)
    end
  end

  defp current_cache_entry do
    case CacheStore.get() do
      {:ok, entry} -> entry
      :miss -> nil
    end
  end

  @spec serve_cached_entry(map(), atom()) :: {:ok, map()}
  defp serve_cached_entry(%{} = cache_entry, reason) do
    payload =
      cache_entry.payload
      |> ensure_counts()
      |> maybe_use_cached_summaries(cache_entry)

    {:ok,
     Map.merge(payload, %{
       cached?: true,
       cached_reason: reason,
       synced_at: cache_entry.synced_at,
       message: cache_entry.rate_limit_message
     })}
  end

  defp perform_remote_sync(cache_entry, now, now_mono) do
    case do_sync_from_linear() do
      {:ok, payload} ->
        handle_sync_success(payload, now, now_mono)

      {:error, {:rate_limited, message}} ->
        handle_sync_rate_limited(cache_entry, message, now_mono)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fresh_cache_decision(%{payload: payload, synced_at_mono: sync_mono} = entry, now_mono)
       when not is_nil(payload) and not is_nil(sync_mono) and
              now_mono - sync_mono <= @sync_cache_fresh_ttl_ms do
    {:ok, entry}
  end

  defp fresh_cache_decision(_, _), do: :no

  defp rate_limited_decision(%{next_allowed_sync_mono: mono, payload: payload} = entry, now_mono)
       when not is_nil(mono) and not is_nil(payload) and now_mono < mono do
    {:ok, entry}
  end

  defp rate_limited_decision(_, _), do: :no

  defp handle_sync_success(payload, now, now_mono) do
    normalized_payload = ensure_counts(payload)

    entry = %{
      payload: normalized_payload,
      synced_at: now,
      synced_at_mono: now_mono,
      next_allowed_sync_mono: nil,
      rate_limit_message: nil,
      summaries: normalized_payload.summaries
    }

    CacheStore.put(entry, @sync_cache_entry_ttl_ms)

    {:ok,
     Map.merge(normalized_payload, %{
       cached?: false,
       cached_reason: :fresh,
       synced_at: now,
       message: nil
     })}
  end

  defp handle_sync_rate_limited(cache_entry, message, now_mono) do
    entry =
      build_rate_limited_entry(cache_entry, message, now_mono + @sync_cache_backoff_ms)

    CacheStore.put(entry, @sync_cache_entry_ttl_ms)

    case entry.payload do
      nil -> {:error, {:rate_limited, message}}
      _ -> serve_cached_entry(entry, :rate_limited)
    end
  end

  defp build_rate_limited_entry(cache_entry, message, next_allowed) do
    %{
      payload: cache_entry && cache_entry.payload,
      synced_at: cache_entry && cache_entry.synced_at,
      synced_at_mono: cache_entry && cache_entry.synced_at_mono,
      next_allowed_sync_mono: next_allowed,
      rate_limit_message: message,
      summaries: cache_entry && cache_entry.summaries
    }
  end

  defp summaries_from_payload(payload) do
    payload
    |> extract_summaries(:summaries)
    |> presence_or_else(fn ->
      extract_summaries(payload, "summaries")
    end)
  end

  defp summaries_from_cache(%{} = cache_entry) do
    cache_entry
    |> extract_summaries(:summaries)
    |> presence_or_else(fn ->
      extract_summaries(cache_entry, "summaries")
    end)
  end

  defp extract_summaries(map, key) do
    case Map.get(map, key) do
      value when is_map(value) and map_size(value) > 0 -> value
      _ -> nil
    end
  end

  defp presence_or_else(nil, fallback), do: fallback.()
  defp presence_or_else(value, _), do: value

  defp runtime_env do
    Application.get_env(:elixir, :config_env, :prod)
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
        {:ok, %{projects: projects, workflow_states: states, members: members}} ->
          sync_workflow_states(team["id"], states)
          sync_team_members(team["id"], members)

          team_name = team["name"]

          entry = %{
            "name" => team_name,
            "id" => team["id"],
            "projects" => projects,
            "linear_team_name" => team_name,
            "members" => members
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

  defp fetch_team_projects(team) do
    Enum.reduce_while(@team_project_queries, {:error, :no_supported_query}, fn {query,
                                                                                members_key},
                                                                               last_error ->
      case fetch_team_projects_with_query(team, query, members_key) do
        {:ok, result} -> {:halt, {:ok, result}}
        {:error, :unsupported} -> {:cont, last_error}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp fetch_team_projects_with_query(team, query, members_key) do
    case do_fetch_team_projects(team, query, members_key) do
      {:ok, result} ->
        {:ok, result}

      {:error, {:http_error, status, body}} = error ->
        if fallback_error?(status, body, members_key) do
          {:error, :unsupported}
        else
          error
        end

      {:error, {:unexpected, %{"errors" => _} = body}} = error ->
        if fallback_error?(nil, body, members_key) do
          {:error, :unsupported}
        else
          error
        end

      other ->
        other
    end
  end

  defp do_fetch_team_projects(team, query, members_key) do
    initial_members = if members_key == :none, do: nil, else: []

    do_fetch_team_projects(
      team,
      query,
      members_key,
      %{projects: [], states: nil, members: initial_members},
      nil
    )
  end

  defp do_fetch_team_projects(team, query, members_key, acc, cursor) do
    team_id = team["id"]

    variables =
      %{"teamId" => team_id, "first" => @projects_page_size}
      |> maybe_put_after(cursor)

    case Integrations.linear_graphql(query, variables) do
      {:ok, %{"data" => %{"team" => nil}}} ->
        {:ok, %{projects: acc.projects, workflow_states: acc.states || [], members: acc.members}}

      {:ok, %{"data" => %{"team" => team_data}}} ->
        updated_acc = append_team_page(team_data, acc, members_key)

        if next_cursor = next_page_cursor(team_data) do
          do_fetch_team_projects(team, query, members_key, updated_acc, next_cursor)
        else
          {:ok,
           %{
             projects: updated_acc.projects,
             workflow_states: updated_acc.states || [],
             members: finalize_members(updated_acc.members, members_key)
           }}
        end

      other ->
        other
    end
  end

  defp append_team_page(team_data, acc, members_key) do
    projects = get_in(team_data, ["projects", "nodes"]) || []
    workflow_states = get_in(team_data, ["states", "nodes"]) || []
    members = collect_members(team_data, members_key)

    acc
    |> Map.update!(:projects, &(&1 ++ projects))
    |> Map.update(:states, workflow_states, fn existing -> existing || workflow_states end)
    |> Map.update(:members, members, fn
      nil -> nil
      list -> list ++ members
    end)
  end

  defp collect_members(_team_data, :none), do: []

  defp collect_members(team_data, :team_memberships) do
    team_data
    |> get_in(["teamMemberships", "nodes"])
    |> List.wrap()
    |> Enum.map(&Map.get(&1, "user"))
    |> Enum.reject(&is_nil/1)
  end

  defp collect_members(team_data, :members) do
    team_data
    |> get_in(["members", "nodes"])
    |> List.wrap()
    |> Enum.reject(&is_nil/1)
  end

  defp next_page_cursor(team_data) do
    case get_in(team_data, ["projects", "pageInfo"]) do
      %{"hasNextPage" => true, "endCursor" => cursor} -> cursor
      _ -> nil
    end
  end

  defp finalize_members(nil, _), do: nil
  defp finalize_members(list, _), do: list

  defp fallback_error?(_, _, :none), do: false

  defp fallback_error?(status, body, members_key) do
    status in [nil, 400, 403] and missing_field_error?(body, members_field_name(members_key))
  end

  defp members_field_name(:team_memberships), do: "teamMemberships"
  defp members_field_name(:members), do: "members"
  defp members_field_name(_), do: nil

  defp missing_field_error?(%{"errors" => errors}, field)
       when is_list(errors) and is_binary(field) do
    Enum.any?(errors, fn error ->
      message =
        error
        |> Map.get("message") || get_in(error, ["extensions", "message"]) ||
          get_in(error, [:message])

      is_binary(message) and
        String.contains?(String.downcase(message), String.downcase(field))
    end)
  end

  defp missing_field_error?(_, _), do: false

  defp maybe_put_after(vars, nil), do: vars
  defp maybe_put_after(vars, cursor), do: Map.put(vars, "after", cursor)

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
    if is_nil(project.client_id) and not is_nil(value) do
      Map.put(acc, :client_id, value)
    else
      acc
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

  defp sync_team_members(_team_id, nil), do: :ok

  defp sync_team_members(team_id, members) when is_list(members) do
    case normalize_team_id(team_id) do
      nil -> :ok
      "" -> :ok
      normalized -> persist_team_members(normalized, members)
    end
  end

  defp normalize_team_id(nil), do: nil
  defp normalize_team_id(team_id) when is_binary(team_id), do: String.trim(team_id)
  defp normalize_team_id(team_id), do: team_id |> to_string() |> String.trim()

  defp persist_team_members(team_id, members) do
    normalized =
      members
      |> Enum.map(&normalize_team_member/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq_by(& &1.linear_user_id)

    case normalized do
      [] ->
        :ok

      _ ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        entries =
          Enum.map(normalized, fn member ->
            %{
              id: Ecto.UUID.generate(),
              linear_team_id: team_id,
              linear_user_id: member.linear_user_id,
              name: member.name,
              display_name: member.display_name,
              email: member.email,
              avatar_url: member.avatar_url,
              inserted_at: now,
              updated_at: now
            }
          end)

        Repo.insert_all(
          LinearTeamMember,
          entries,
          on_conflict:
            {:replace, [:linear_team_id, :name, :display_name, :email, :avatar_url, :updated_at]},
          conflict_target: [:linear_team_id, :linear_user_id]
        )

        user_ids = Enum.map(normalized, & &1.linear_user_id)

        from(m in LinearTeamMember,
          where: m.linear_team_id == ^team_id and m.linear_user_id not in ^user_ids
        )
        |> Repo.delete_all()

        :ok
    end
  end

  @doc """
  Returns Linear team members grouped by `linear_team_id` for the provided IDs.
  """
  @spec team_members_by_team_ids([String.t()]) :: %{
          optional(String.t()) => [LinearTeamMember.t()]
        }
  def team_members_by_team_ids([]), do: %{}
  def team_members_by_team_ids(nil), do: %{}

  def team_members_by_team_ids(team_ids) when is_list(team_ids) do
    from(m in LinearTeamMember, where: m.linear_team_id in ^team_ids)
    |> Repo.all()
    |> Enum.group_by(& &1.linear_team_id)
  end

  defp normalize_team_member(nil), do: nil
  defp normalize_team_member(%{"user" => user}) when is_map(user), do: normalize_team_member(user)
  defp normalize_team_member(%{user: user}) when is_map(user), do: normalize_team_member(user)

  defp normalize_team_member(%{"id" => id} = member) when is_binary(id) do
    %{
      linear_user_id: id,
      name: Map.get(member, "name"),
      display_name: Map.get(member, "displayName"),
      email: Map.get(member, "email"),
      avatar_url: Map.get(member, "avatarUrl")
    }
  end

  defp normalize_team_member(%{"id" => id} = member) when not is_nil(id) do
    normalize_team_member(Map.put(member, "id", to_string(id)))
  end

  defp normalize_team_member(%{id: id} = member) when is_binary(id) do
    %{
      linear_user_id: id,
      name: Map.get(member, :name) || Map.get(member, "name"),
      display_name:
        Map.get(member, :display_name) || Map.get(member, "display_name") ||
          Map.get(member, "displayName"),
      email: Map.get(member, :email) || Map.get(member, "email"),
      avatar_url:
        Map.get(member, :avatar_url) || Map.get(member, "avatar_url") ||
          Map.get(member, "avatarUrl")
    }
  end

  defp normalize_team_member(%{id: id} = member) when not is_nil(id) do
    normalize_team_member(Map.put(member, :id, to_string(id)))
  end

  defp normalize_team_member(_), do: nil

  @doc """
  Returns a map of workflow state metadata for the given Linear team.
  """
  @spec workflow_state_metadata(String.t() | nil) :: map()
  def workflow_state_metadata(nil), do: %{}

  def workflow_state_metadata(team_id) do
    workflow_state_metadata_multi([team_id]) |> Map.get(team_id, %{})
  end

  @doc false
  @spec workflow_state_metadata_multi([String.t() | nil]) :: map()
  def workflow_state_metadata_multi(team_ids) do
    team_ids
    |> Enum.filter(&is_binary/1)
    |> Enum.reject(&(&1 == ""))
    |> case do
      [] -> %{}
      ids -> build_workflow_state_map(ids)
    end
  end

  defp build_workflow_state_map(team_ids) do
    from(s in LinearWorkflowState, where: s.linear_team_id in ^team_ids)
    |> Repo.all()
    |> Enum.group_by(& &1.linear_team_id, fn state -> state end)
    |> Enum.into(%{}, fn {team_id, states} -> {team_id, build_state_entries(states)} end)
  end

  defp build_state_entries(states) do
    Enum.reduce(states, %{}, fn state, acc ->
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
