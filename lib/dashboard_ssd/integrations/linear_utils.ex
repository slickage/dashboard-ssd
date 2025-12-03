defmodule DashboardSSD.Integrations.LinearUtils do
  @moduledoc """
  Shared utilities for Linear integration, including issue fetching and summarization.

    - Provides GraphQL queries/helpers to fetch Linear issues by project name/ID.
  - Supplies workload summarization helpers used by dashboards and cache warmers.
  - Offers feature flags (`linear_enabled?/0`) and resilient fallbacks when Linear is disabled.
  """

  alias DashboardSSD.{Integrations, Projects}

  @issues_page_size 100

  @issues_by_project_query """
  query IssuesByProjectId($projectId: String!, $first:Int!, $after:String) {
    issues(
      first: $first
      after: $after
      filter: { project: { id: { eq: $projectId } } }
    ) {
      nodes {
        id
        state { id name type }
        assignee { id name displayName email }
      }
      pageInfo { hasNextPage endCursor }
    }
  }
  """

  @doc """
  Fetches issue nodes for a project by name (fallback when project ID is unavailable).
  """
  @spec issue_nodes_for_project(String.t()) :: {:ok, list()} | :empty | :error
  def issue_nodes_for_project(name) do
    eq_query = """
    query IssuesByProject($name: String!, $first: Int!) {
      issues(first: $first, filter: { project: { name: { eq: $name } } }) {
        nodes {
          id
          state { id name type }
          assignee { id name displayName email }
        }
      }
    }
    """

    contains_query = """
    query IssuesByProjectContains($name: String!, $first: Int!) {
      issues(first: $first, filter: { project: { name: { contains: $name } } }) {
        nodes {
          id
          state { id name type }
          assignee { id name displayName email }
        }
      }
    }
    """

    search_query = """
    query IssueSearch($q: String!) {
      issueSearch(query: $q, first: 50) {
        nodes {
          id
          state { id name type }
          assignee { id name displayName email }
        }
      }
    }
    """

    queries = [
      {eq_query, %{"name" => name, "first" => 50}},
      {contains_query, %{"name" => name, "first" => 50}},
      {search_query, %{"q" => ~s(project:"#{name}")}}
    ]

    try_issue_queries(queries)
  end

  @doc """
  Tries the provided Linear queries in order until a successful response is returned.
  """
  @spec try_issue_queries(list()) :: {:ok, list()} | :empty | :error
  def try_issue_queries([{query, vars} | rest]) do
    case Integrations.linear_list_issues(query, vars) do
      {:ok, %{"data" => %{"issues" => %{"nodes" => nodes}}}} when is_list(nodes) ->
        {:ok, nodes}

      {:ok, %{"data" => %{"issueSearch" => %{"nodes" => nodes}}}} when is_list(nodes) ->
        {:ok, nodes}

      {:ok, _} ->
        try_issue_queries(rest)

      {:error, _} ->
        if rest == [], do: :error, else: try_issue_queries(rest)
    end
  end

  @spec try_issue_queries([]) :: :empty
  def try_issue_queries([]), do: :empty

  @doc """
  Fetches issue nodes by Linear project ID.
  """
  @spec issue_nodes_for_project_id(String.t()) :: {:ok, list()} | :empty | {:error, term()}
  def issue_nodes_for_project_id(project_id),
    do: issue_nodes_for_project_id(project_id, [], nil, :ok)

  defp issue_nodes_for_project_id(_project_id, acc, _cursor, :empty) when acc == [], do: :empty
  defp issue_nodes_for_project_id(_project_id, acc, _cursor, :empty), do: {:ok, acc}

  defp issue_nodes_for_project_id(_project_id, _acc, _cursor, {:error, reason}),
    do: {:error, reason}

  defp issue_nodes_for_project_id(project_id, acc, cursor, _status) do
    variables =
      %{"projectId" => project_id, "first" => @issues_page_size}
      |> maybe_put_after(cursor)

    case Integrations.linear_list_issues(@issues_by_project_query, variables) do
      {:ok,
       %{
         "data" => %{
           "issues" => %{
             "nodes" => nodes,
             "pageInfo" => %{"hasNextPage" => true, "endCursor" => end_cursor}
           }
         }
       }} ->
        issue_nodes_for_project_id(project_id, acc ++ nodes, end_cursor, :ok)

      {:ok,
       %{
         "data" => %{
           "issues" => %{
             "nodes" => nodes,
             "pageInfo" => %{"hasNextPage" => false}
           }
         }
       }} ->
        {:ok, acc ++ (nodes || [])}

      {:ok, %{"data" => %{"issues" => %{"nodes" => nil}}}} ->
        issue_nodes_for_project_id(project_id, acc, cursor, :empty)

      {:ok, other} ->
        issue_nodes_for_project_id(project_id, acc, cursor, {:error, {:unexpected, other}})

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Summarizes issue nodes into totals broken down by workflow state and assignee.
  """
  @spec summarize_issue_nodes(list(), map()) :: %{
          total: integer(),
          in_progress: integer(),
          finished: integer(),
          assigned: list()
        }
  def summarize_issue_nodes(nodes, state_metadata \\ %{}) when is_list(nodes) do
    total = length(nodes)
    summary = summarize_nodes(nodes, state_metadata)

    assigned =
      summary.assigned
      |> Map.values()
      |> Enum.reject(&is_nil(&1.name))
      |> Enum.sort_by(fn %{count: count, name: name} ->
        {-count, String.downcase(name)}
      end)

    %{
      total: total,
      in_progress: summary.in_progress,
      finished: summary.finished,
      assigned: assigned
    }
  end

  @doc """
  Reduces issue nodes to the number in progress and completed.
  """
  @spec summarize_nodes(list(), map()) :: %{
          in_progress: integer(),
          finished: integer(),
          assigned: map()
        }
  def summarize_nodes(nodes, state_metadata \\ %{}) do
    Enum.reduce(nodes, %{in_progress: 0, finished: 0, assigned: %{}}, fn node, acc ->
      acc
      |> increment_counts(node, state_metadata)
      |> increment_assignee(node)
    end)
  end

  defp increment_counts(acc, node, state_metadata) do
    state = node["state"] || %{}
    state_id = state["id"]

    state_type =
      state["type"] ||
        get_in(state_metadata, [state_id, :type]) ||
        get_in(state_metadata, [state_id, "type"])

    cond do
      normalize_state_type(state_type) in [:completed, :canceled] ->
        Map.update!(acc, :finished, &(&1 + 1))

      normalize_state_type(state_type) == :started ->
        Map.update!(acc, :in_progress, &(&1 + 1))

      true ->
        summarize_by_name(state["name"], acc)
    end
  end

  defp summarize_by_name(nil, acc), do: acc

  defp summarize_by_name(name, acc) do
    normalized = String.downcase(name || "")

    cond do
      done_keyword?(normalized) -> Map.update!(acc, :finished, &(&1 + 1))
      in_progress_keyword?(normalized) -> Map.update!(acc, :in_progress, &(&1 + 1))
      true -> acc
    end
  end

  defp increment_assignee(acc, %{"assignee" => %{} = assignee}) do
    with key when not is_nil(key) <- assignee_key(assignee),
         assigned <- Map.fetch!(acc, :assigned) do
      updated = upsert_assignee(assigned, key, assignee["id"], assignee_name(assignee))
      %{acc | assigned: updated}
    else
      _ -> acc
    end
  end

  defp increment_assignee(acc, _), do: acc

  defp assignee_key(%{"id" => id}) when is_binary(id), do: id
  defp assignee_key(%{"email" => email}) when is_binary(email), do: email
  defp assignee_key(%{"displayName" => name}) when is_binary(name), do: name
  defp assignee_key(%{"name" => name}) when is_binary(name), do: name
  defp assignee_key(_), do: nil

  defp assignee_name(%{"displayName" => name}) when is_binary(name), do: name
  defp assignee_name(%{"name" => name}) when is_binary(name), do: name
  defp assignee_name(%{"email" => email}) when is_binary(email), do: email
  defp assignee_name(_), do: nil

  defp upsert_assignee(assigned, key, id, name) do
    Map.update(assigned, key, %{id: id, name: name, count: 1}, fn current ->
      %{current | count: current.count + 1}
    end)
  end

  @doc """
  Fetches and summarizes Linear issue counts for a project.
  """
  @spec fetch_linear_summary(map()) ::
          %{total: integer(), in_progress: integer(), finished: integer(), assigned: list()}
          | :unavailable
  @spec fetch_linear_summary(map(), keyword()) ::
          %{total: integer(), in_progress: integer(), finished: integer(), assigned: list()}
          | :unavailable
  def fetch_linear_summary(project, opts \\ []) do
    if Application.get_env(:dashboard_ssd, :env) == :test and
         Application.get_env(:tesla, :adapter) != Tesla.Mock do
      :unavailable
    else
      do_fetch_linear_summary(project, opts)
    end
  end

  @doc false
  @spec do_fetch_linear_summary(map(), keyword()) ::
          %{total: integer(), in_progress: integer(), finished: integer(), assigned: list()}
          | :unavailable
  def do_fetch_linear_summary(project, opts \\ []) do
    team_id = linear_team_id(project)

    state_metadata =
      cond do
        is_map(opts[:state_metadata]) and is_binary(team_id) ->
          map = opts[:state_metadata]
          Map.get(map, team_id, %{})

        is_binary(team_id) ->
          Projects.workflow_state_metadata(team_id)

        true ->
          %{}
      end

    case issues_for_project(project) do
      {:ok, nodes} -> summarize_issue_nodes(nodes, state_metadata)
      :empty -> %{total: 0, in_progress: 0, finished: 0, assigned: []}
      _ -> :unavailable
    end
  end

  defp issues_for_project(project) do
    project
    |> linear_project_id()
    |> try_project_id()
    |> resolve_project_issues(project_name(project))
  end

  defp try_project_id(nil), do: nil
  defp try_project_id(project_id), do: issue_nodes_for_project_id(project_id)

  defp resolve_project_issues({:ok, _} = ok, _name), do: ok
  defp resolve_project_issues(_result, name), do: project_issues_by_name(name)

  defp project_issues_by_name(nil), do: :empty

  defp project_issues_by_name(name) do
    case issue_nodes_for_project(name) do
      {:ok, _} = ok -> ok
      other -> other
    end
  end

  defp project_name(project), do: Map.get(project, :name) || Map.get(project, "name")

  defp linear_project_id(project) do
    Map.get(project, :linear_project_id) || Map.get(project, "linear_project_id")
  end

  defp linear_team_id(project) do
    Map.get(project, :linear_team_id) || Map.get(project, "linear_team_id")
  end

  @doc """
  Determines if the Linear integration is configured.
  """
  @spec linear_enabled?() :: boolean()
  def linear_enabled? do
    config_token = Application.get_env(:dashboard_ssd, :integrations, [])[:linear_token]
    env_token = System.get_env("LINEAR_TOKEN")
    env_api_key = System.get_env("LINEAR_API_KEY")

    present?(config_token) or present?(env_token) or present?(env_api_key)
  end

  defp normalize_state_type(nil), do: nil

  defp normalize_state_type(type) when is_binary(type) do
    case String.downcase(type) do
      "completed" -> :completed
      "started" -> :started
      "backlog" -> :backlog
      "canceled" -> :canceled
      other when other in ["done"] -> :completed
      _ -> nil
    end
  end

  defp normalize_state_type(_), do: nil

  defp done_keyword?(state_name) do
    Enum.any?(
      ["done", "complete", "completed", "closed", "merged", "released", "shipped", "resolved"],
      &String.contains?(state_name, &1)
    )
  end

  defp in_progress_keyword?(state_name) do
    Enum.any?(
      ["progress", "doing", "started", "active", "review", "qa", "testing", "block", "verify"],
      &String.contains?(state_name, &1)
    )
  end

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(value) when is_list(value), do: value |> to_string() |> present?()
  defp present?(_), do: false

  defp maybe_put_after(vars, nil), do: vars
  defp maybe_put_after(vars, cursor), do: Map.put(vars, "after", cursor)
end
