defmodule DashboardSSD.Clients do
  @moduledoc """
  Clients context: manage client records.
  """
  import Ecto.Query, warn: false
  alias DashboardSSD.Clients.Client
  alias DashboardSSD.Repo
  alias Phoenix.PubSub

  @topic "clients"

  @doc "Subscribe to client change notifications."
  @spec subscribe() :: :ok
  def subscribe do
    PubSub.subscribe(DashboardSSD.PubSub, @topic)
  end

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
    %Client{}
    |> Client.changeset(attrs)
    |> Repo.insert()
    |> broadcast(:created)
  end

  @doc "Update an existing client"
  @spec update_client(Client.t(), map()) :: {:ok, Client.t()} | {:error, Ecto.Changeset.t()}
  def update_client(%Client{} = client, attrs) do
    client
    |> Client.changeset(attrs)
    |> Repo.update()
    |> broadcast(:updated)
  end

  @doc "Delete a client"
  @spec delete_client(Client.t()) :: {:ok, Client.t()} | {:error, Ecto.Changeset.t()}
  def delete_client(%Client{} = client) do
    client
    |> Repo.delete()
    |> broadcast(:deleted)
  end

  @doc "Search clients by name (case-insensitive, partial match)."
  @spec search_clients(String.t()) :: [Client.t()]
  def search_clients(term) when is_binary(term) do
    like = "%" <> String.replace(term, "%", "\\%") <> "%"
    from(c in Client, where: ilike(c.name, ^like)) |> Repo.all()
  end

  def search_clients(_), do: list_clients()

  @doc "Ensure a client with the given name exists, returning it."
  @spec ensure_client!(String.t()) :: Client.t()
  def ensure_client!(name) when is_binary(name) do
    Repo.get_by(Client, name: name) ||
      %Client{} |> Client.changeset(%{name: name}) |> Repo.insert!()
  end

  defp broadcast({:ok, client}, event) do
    PubSub.broadcast(DashboardSSD.PubSub, @topic, {:client, event, client})
    {:ok, client}
  end

  defp broadcast({:error, _} = error, _event), do: error
end
