defmodule DashboardSSD.Integrations.LinearUtils do
  @moduledoc """
  Shared utilities for Linear integration, including issue fetching and summarization.
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
      nodes { id state { id name type } }
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
        nodes { id state { id name type } }
      }
    }
    """

    contains_query = """
    query IssuesByProjectContains($name: String!, $first: Int!) {
      issues(first: $first, filter: { project: { name: { contains: $name } } }) {
        nodes { id state { id name type } }
      }
    }
    """

    search_query = """
    query IssueSearch($q: String!) {
      issueSearch(query: $q, first: 50) {
        nodes { id state { id name type } }
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
  Summarizes issue nodes into totals broken down by workflow state.
  """
  @spec summarize_issue_nodes(list(), map()) :: %{
          total: integer(),
          in_progress: integer(),
          finished: integer()
        }
  def summarize_issue_nodes(nodes, state_metadata \\ %{}) when is_list(nodes) do
    total = length(nodes)
    {in_progress, finished} = summarize_nodes(nodes, state_metadata)
    %{total: total, in_progress: in_progress, finished: finished}
  end

  @doc """
  Reduces issue nodes to the number in progress and completed.
  """
  @spec summarize_nodes(list(), map()) :: {integer(), integer()}
  def summarize_nodes(nodes, state_metadata \\ %{}) do
    Enum.reduce(nodes, {0, 0}, fn node, {ip, fin} ->
      state = node["state"] || %{}
      state_id = state["id"]

      state_type =
        state["type"] ||
          get_in(state_metadata, [state_id, :type]) ||
          get_in(state_metadata, [state_id, "type"])

      case normalize_state_type(state_type) do
        :completed -> {ip, fin + 1}
        :canceled -> {ip, fin + 1}
        :started -> {ip + 1, fin}
        :backlog -> {ip, fin}
        _ -> summarize_by_name(state["name"], ip, fin)
      end
    end)
  end

  defp summarize_by_name(nil, ip, fin), do: {ip, fin}

  defp summarize_by_name(name, ip, fin) do
    normalized = String.downcase(name)

    cond do
      done_keyword?(normalized) -> {ip, fin + 1}
      in_progress_keyword?(normalized) -> {ip + 1, fin}
      true -> {ip, fin}
    end
  end

  @doc """
  Fetches and summarizes Linear issue counts for a project.
  """
  @spec fetch_linear_summary(map()) ::
          %{total: integer(), in_progress: integer(), finished: integer()} | :unavailable
  def fetch_linear_summary(project) do
    if Application.get_env(:dashboard_ssd, :env) == :test and
         Application.get_env(:tesla, :adapter) != Tesla.Mock do
      :unavailable
    else
      do_fetch_linear_summary(project)
    end
  end

  @doc false
  @spec do_fetch_linear_summary(map()) ::
          %{total: integer(), in_progress: integer(), finished: integer()} | :unavailable
  def do_fetch_linear_summary(project) do
    state_metadata =
      project
      |> linear_team_id()
      |> Projects.workflow_state_metadata()

    case issues_for_project(project) do
      {:ok, nodes} -> summarize_issue_nodes(nodes, state_metadata)
      :empty -> %{total: 0, in_progress: 0, finished: 0}
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
