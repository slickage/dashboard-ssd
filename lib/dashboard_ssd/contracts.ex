defmodule DashboardSSD.Contracts do
  @moduledoc """
  Contracts context: manage SOWs and Change Requests.
  """
  import Ecto.Query, warn: false
  alias DashboardSSD.Contracts.{ChangeRequest, SOW}
  alias DashboardSSD.Repo

  # SOWs
  @doc """
  Lists all SOWs ordered by insertion time.

  Returns a list of SOW structs.
  """
  @spec list_sows() :: [SOW.t()]
  def list_sows, do: Repo.all(SOW)

  @doc """
  Lists all SOWs for a specific project.

  Returns SOWs ordered by insertion time (most recent first).
  """
  @spec list_sows_by_project(pos_integer()) :: [SOW.t()]
  def list_sows_by_project(project_id) do
    from(s in SOW, where: s.project_id == ^project_id) |> Repo.all()
  end

  @doc """
  Fetches a SOW by ID.

  Raises Ecto.NoResultsError if the SOW does not exist.
  """
  @spec get_sow!(pos_integer()) :: SOW.t()
  def get_sow!(id), do: Repo.get!(SOW, id)

  @doc """
  Returns a changeset for tracking SOW changes.

  Validates the given attributes against the SOW schema.
  """
  @spec change_sow(SOW.t(), map()) :: Ecto.Changeset.t()
  def change_sow(%SOW{} = sow, attrs \\ %{}), do: SOW.changeset(sow, attrs)

  @doc """
  Creates a new SOW with the given attributes.

  Returns {:ok, sow} on success or {:error, changeset} on validation failure.
  """
  @spec create_sow(map()) :: {:ok, SOW.t()} | {:error, Ecto.Changeset.t()}
  def create_sow(attrs), do: %SOW{} |> SOW.changeset(attrs) |> Repo.insert()

  @doc """
  Updates an existing SOW with the given attributes.

  Returns {:ok, sow} on success or {:error, changeset} on validation failure.
  """
  @spec update_sow(SOW.t(), map()) :: {:ok, SOW.t()} | {:error, Ecto.Changeset.t()}
  def update_sow(%SOW{} = sow, attrs), do: sow |> SOW.changeset(attrs) |> Repo.update()

  @doc """
  Deletes a SOW from the database.

  Returns {:ok, sow} on success or {:error, changeset} on constraint violation.
  """
  @spec delete_sow(SOW.t()) :: {:ok, SOW.t()} | {:error, Ecto.Changeset.t()}
  def delete_sow(%SOW{} = sow), do: Repo.delete(sow)

  # Change Requests
  @doc """
  Lists all Change Requests ordered by insertion time.

  Returns a list of ChangeRequest structs.
  """
  @spec list_change_requests() :: [ChangeRequest.t()]
  def list_change_requests, do: Repo.all(ChangeRequest)

  @doc """
  Lists all Change Requests for a specific project.

  Returns Change Requests ordered by insertion time (most recent first).
  """
  @spec list_change_requests_by_project(pos_integer()) :: [ChangeRequest.t()]
  def list_change_requests_by_project(project_id) do
    from(c in ChangeRequest, where: c.project_id == ^project_id) |> Repo.all()
  end

  @doc """
  Fetches a Change Request by ID.

  Raises Ecto.NoResultsError if the Change Request does not exist.
  """
  @spec get_change_request!(pos_integer()) :: ChangeRequest.t()
  def get_change_request!(id), do: Repo.get!(ChangeRequest, id)

  @doc """
  Returns a changeset for tracking Change Request changes.

  Validates the given attributes against the Change Request schema.
  """
  @spec change_change_request(ChangeRequest.t(), map()) :: Ecto.Changeset.t()
  def change_change_request(%ChangeRequest{} = cr, attrs \\ %{}),
    do: ChangeRequest.changeset(cr, attrs)

  @doc """
  Creates a new Change Request with the given attributes.

  Returns {:ok, change_request} on success or {:error, changeset} on validation failure.
  """
  @spec create_change_request(map()) :: {:ok, ChangeRequest.t()} | {:error, Ecto.Changeset.t()}
  def create_change_request(attrs),
    do: %ChangeRequest{} |> ChangeRequest.changeset(attrs) |> Repo.insert()

  @doc """
  Updates an existing Change Request with the given attributes.

  Returns {:ok, change_request} on success or {:error, changeset} on validation failure.
  """
  @spec update_change_request(ChangeRequest.t(), map()) ::
          {:ok, ChangeRequest.t()} | {:error, Ecto.Changeset.t()}
  def update_change_request(%ChangeRequest{} = cr, attrs),
    do: cr |> ChangeRequest.changeset(attrs) |> Repo.update()

  @doc """
  Deletes a Change Request from the database.

  Returns {:ok, change_request} on success or {:error, changeset} on constraint violation.
  """
  @spec delete_change_request(ChangeRequest.t()) ::
          {:ok, ChangeRequest.t()} | {:error, Ecto.Changeset.t()}
  def delete_change_request(%ChangeRequest{} = cr), do: Repo.delete(cr)
end
