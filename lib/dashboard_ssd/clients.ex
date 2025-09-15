defmodule DashboardSSD.Clients do
  @moduledoc """
  Clients context: manage client records.
  """
  import Ecto.Query, warn: false
  alias DashboardSSD.Clients.Client
  alias DashboardSSD.Repo

  @doc "List all clients"
  @spec list_clients() :: [Client.t()]
  def list_clients, do: Repo.all(Client)

  @doc "Fetch a client by id, raising if not found"
  @spec get_client!(pos_integer()) :: Client.t()
  def get_client!(id), do: Repo.get!(Client, id)

  @doc "Return a changeset for a client with proposed changes"
  @spec change_client(Client.t(), map()) :: Ecto.Changeset.t()
  def change_client(%Client{} = client, attrs \\ %{}), do: Client.changeset(client, attrs)

  @doc "Create a new client"
  @spec create_client(map()) :: {:ok, Client.t()} | {:error, Ecto.Changeset.t()}
  def create_client(attrs) do
    %Client{} |> Client.changeset(attrs) |> Repo.insert()
  end

  @doc "Update an existing client"
  @spec update_client(Client.t(), map()) :: {:ok, Client.t()} | {:error, Ecto.Changeset.t()}
  def update_client(%Client{} = client, attrs) do
    client |> Client.changeset(attrs) |> Repo.update()
  end

  @doc "Delete a client"
  @spec delete_client(Client.t()) :: {:ok, Client.t()} | {:error, Ecto.Changeset.t()}
  def delete_client(%Client{} = client) do
    Repo.delete(client)
  end
end
