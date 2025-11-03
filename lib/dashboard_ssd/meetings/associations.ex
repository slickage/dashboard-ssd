defmodule DashboardSSD.Meetings.Associations do
  @moduledoc "Context functions for meeting-to-client/project association management."
  import Ecto.Query
  alias DashboardSSD.Repo
  alias DashboardSSD.Meetings.MeetingAssociation

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
end

