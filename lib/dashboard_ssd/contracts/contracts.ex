defmodule DashboardSSD.Contracts do
  @moduledoc """
  Contracts context: manage SOWs and Change Requests.
  """
  import Ecto.Query, warn: false
  alias DashboardSSD.Contracts.{ChangeRequest, SOW}
  alias DashboardSSD.Repo

  # SOWs
  @doc "List all SOWs"
  @spec list_sows() :: [SOW.t()]
  def list_sows, do: Repo.all(SOW)

  @doc "List SOWs by project id"
  @spec list_sows_by_project(pos_integer()) :: [SOW.t()]
  def list_sows_by_project(project_id) do
    from(s in SOW, where: s.project_id == ^project_id) |> Repo.all()
  end

  @doc "Fetch a SOW by id"
  @spec get_sow!(pos_integer()) :: SOW.t()
  def get_sow!(id), do: Repo.get!(SOW, id)

  @doc "Return a changeset for a SOW"
  @spec change_sow(SOW.t(), map()) :: Ecto.Changeset.t()
  def change_sow(%SOW{} = sow, attrs \\ %{}), do: SOW.changeset(sow, attrs)

  @doc "Create a SOW"
  @spec create_sow(map()) :: {:ok, SOW.t()} | {:error, Ecto.Changeset.t()}
  def create_sow(attrs), do: %SOW{} |> SOW.changeset(attrs) |> Repo.insert()

  @doc "Update a SOW"
  @spec update_sow(SOW.t(), map()) :: {:ok, SOW.t()} | {:error, Ecto.Changeset.t()}
  def update_sow(%SOW{} = sow, attrs), do: sow |> SOW.changeset(attrs) |> Repo.update()

  @doc "Delete a SOW"
  @spec delete_sow(SOW.t()) :: {:ok, SOW.t()} | {:error, Ecto.Changeset.t()}
  def delete_sow(%SOW{} = sow), do: Repo.delete(sow)

  # Change Requests
  @doc "List all Change Requests"
  @spec list_change_requests() :: [ChangeRequest.t()]
  def list_change_requests, do: Repo.all(ChangeRequest)

  @doc "List Change Requests by project id"
  @spec list_change_requests_by_project(pos_integer()) :: [ChangeRequest.t()]
  def list_change_requests_by_project(project_id) do
    from(c in ChangeRequest, where: c.project_id == ^project_id) |> Repo.all()
  end

  @doc "Fetch a Change Request by id"
  @spec get_change_request!(pos_integer()) :: ChangeRequest.t()
  def get_change_request!(id), do: Repo.get!(ChangeRequest, id)

  @doc "Return a changeset for a Change Request"
  @spec change_change_request(ChangeRequest.t(), map()) :: Ecto.Changeset.t()
  def change_change_request(%ChangeRequest{} = cr, attrs \\ %{}),
    do: ChangeRequest.changeset(cr, attrs)

  @doc "Create a Change Request"
  @spec create_change_request(map()) :: {:ok, ChangeRequest.t()} | {:error, Ecto.Changeset.t()}
  def create_change_request(attrs),
    do: %ChangeRequest{} |> ChangeRequest.changeset(attrs) |> Repo.insert()

  @doc "Update a Change Request"
  @spec update_change_request(ChangeRequest.t(), map()) ::
          {:ok, ChangeRequest.t()} | {:error, Ecto.Changeset.t()}
  def update_change_request(%ChangeRequest{} = cr, attrs),
    do: cr |> ChangeRequest.changeset(attrs) |> Repo.update()

  @doc "Delete a Change Request"
  @spec delete_change_request(ChangeRequest.t()) ::
          {:ok, ChangeRequest.t()} | {:error, Ecto.Changeset.t()}
  def delete_change_request(%ChangeRequest{} = cr), do: Repo.delete(cr)
end
