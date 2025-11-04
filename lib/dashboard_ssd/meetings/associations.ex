defmodule DashboardSSD.Meetings.Associations do
  @moduledoc "Context functions for meeting-to-client/project association management."
  import Ecto.Query
  alias DashboardSSD.Repo
  alias DashboardSSD.Meetings.MeetingAssociation
  alias DashboardSSD.{Clients, Projects}

  @spec get_for_event(String.t()) :: MeetingAssociation.t() | nil
  def get_for_event(calendar_event_id) do
    from(a in MeetingAssociation,
      where: a.calendar_event_id == ^calendar_event_id,
      limit: 1
    )
    |> Repo.one()
  end

  @spec upsert_for_event(String.t(), map()) :: {:ok, MeetingAssociation.t()} | {:error, Ecto.Changeset.t()}
  def upsert_for_event(calendar_event_id, attrs) do
    case get_for_event(calendar_event_id) do
      nil ->
        %MeetingAssociation{calendar_event_id: calendar_event_id}
        |> MeetingAssociation.changeset(attrs)
        |> Repo.insert()

      assoc ->
        assoc
        |> MeetingAssociation.changeset(attrs)
        |> Repo.update()
    end
  end

  @spec set_manual(String.t(), map()) :: {:ok, MeetingAssociation.t()} | {:error, Ecto.Changeset.t()}
  def set_manual(calendar_event_id, %{client_id: _} = attrs),
    do: upsert_for_event(calendar_event_id, Map.merge(attrs, %{origin: "manual"}))

  def set_manual(calendar_event_id, %{project_id: _} = attrs),
    do: upsert_for_event(calendar_event_id, Map.merge(attrs, %{origin: "manual"}))

  @doc """
  Sets manual association and optionally persists for the series.

  If `persist_series` is true and `series_id` is provided, stores the
  `recurring_series_id` and `persist_series` flags so future occurrences can be
  auto-associated.
  """
  @spec set_manual(String.t(), map(), String.t() | nil, boolean()) ::
          {:ok, MeetingAssociation.t()} | {:error, Ecto.Changeset.t()}
  def set_manual(calendar_event_id, attrs, series_id, persist_series) do
    base = %{origin: "manual", persist_series: !!persist_series}
    extend = if series_id, do: Map.put(base, :recurring_series_id, series_id), else: base
    upsert_for_event(calendar_event_id, Map.merge(attrs, extend))
  end

  @doc """
  Attempts to guess a Client or Project association from the meeting title.

  Returns {:client, client} | {:project, project} | :unknown | {:ambiguous, list}.
  """
  @spec guess_from_title(String.t()) :: {:client, Clients.Client.t()} | {:project, Projects.Project.t()} | :unknown | {:ambiguous, list()}
  def guess_from_title(title) when is_binary(title) do
    t = String.downcase(title)
    clients = Clients.list_clients()
    client_matches = Enum.filter(clients, fn c -> c.name && String.contains?(t, String.downcase(c.name)) end)

    projects = Projects.list_projects()
    project_matches = Enum.filter(projects, fn p -> p.name && String.contains?(t, String.downcase(p.name)) end)

    cond do
      length(client_matches) == 1 and project_matches == [] -> {:client, hd(client_matches)}
      length(project_matches) == 1 and client_matches == [] -> {:project, hd(project_matches)}
      client_matches == [] and project_matches == [] -> :unknown
      true -> {:ambiguous, client_matches ++ project_matches}
    end
  end
end
