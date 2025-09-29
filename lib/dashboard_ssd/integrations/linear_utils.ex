defmodule DashboardSSD.Integrations.LinearUtils do
  @moduledoc """
  Shared utilities for Linear integration, including issue fetching and summarization.
  """

  alias DashboardSSD.Integrations

  @doc """
  Fetches issue nodes for a project by name.
  """
  @spec issue_nodes_for_project(String.t()) :: {:ok, list()} | :empty | :error
  def issue_nodes_for_project(name) do
    eq_query = """
    query IssuesByProject($name: String!, $first: Int!) {
      issues(first: $first, filter: { project: { name: { eq: $name } } }) {
        nodes { id state { name } }
      }
    }
    """

    contains_query = """
    query IssuesByProjectContains($name: String!, $first: Int!) {
      issues(first: $first, filter: { project: { name: { contains: $name } } }) {
        nodes { id state { name } }
      }
    }
    """

    search_query = """
    query IssueSearch($q: String!) {
      issueSearch(query: $q, first: 50) {
        nodes { id state { name } }
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
  Tries a list of queries until one succeeds.
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
  Summarizes issue nodes into total, in_progress, finished counts.
  """
  @spec summarize_issue_nodes(list()) :: %{
          total: integer(),
          in_progress: integer(),
          finished: integer()
        }
  def summarize_issue_nodes(nodes) when is_list(nodes) do
    total = length(nodes)
    {in_progress, finished} = summarize_nodes(nodes)
    %{total: total, in_progress: in_progress, finished: finished}
  end

  @doc """
  Summarizes nodes by state.
  """
  @spec summarize_nodes(list()) :: {integer(), integer()}
  def summarize_nodes(nodes) do
    Enum.reduce(nodes, {0, 0}, fn n, {ip, fin} ->
      s = String.downcase(get_in(n, ["state", "name"]) || "")

      done? =
        Enum.any?(
          [
            "done",
            "complete",
            "completed",
            "closed",
            "merged",
            "released",
            "shipped",
            "resolved"
          ],
          &String.contains?(s, &1)
        )

      inprog? =
        Enum.any?(
          [
            "progress",
            "doing",
            "started",
            "active",
            "review",
            "qa",
            "testing",
            "block",
            "verify"
          ],
          &String.contains?(s, &1)
        )

      cond do
        done? -> {ip, fin + 1}
        inprog? -> {ip + 1, fin}
        true -> {ip, fin}
      end
    end)
  end

  @doc """
  Fetches and summarizes Linear summary for a project.
  """
  @spec fetch_linear_summary(map()) ::
          %{total: integer(), in_progress: integer(), finished: integer()} | :unavailable
  def fetch_linear_summary(project) do
    if Application.get_env(:dashboard_ssd, :env) == :test do
      if Application.get_env(:tesla, :adapter) == Tesla.Mock do
        do_fetch_linear_summary(project)
      else
        :unavailable
      end
    else
      do_fetch_linear_summary(project)
    end
  end

  @doc """
  Performs the actual fetch and summary.
  """
  @spec do_fetch_linear_summary(map()) ::
          %{total: integer(), in_progress: integer(), finished: integer()} | :unavailable
  def do_fetch_linear_summary(project) do
    case issue_nodes_for_project(project.name) do
      {:ok, nodes} -> summarize_issue_nodes(nodes)
      :empty -> %{total: 0, in_progress: 0, finished: 0}
      :error -> :unavailable
    end
  end

  @doc """
  Checks if Linear is enabled.
  """
  @spec linear_enabled?() :: boolean()
  def linear_enabled? do
    token = Application.get_env(:dashboard_ssd, :integrations, [])[:linear_token]
    is_binary(token) and String.trim(to_string(token)) != ""
  end
end
