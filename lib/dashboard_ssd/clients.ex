defmodule DashboardSSD.Clients do
  @moduledoc """
  Clients context: manage client records.

    - Publishes CRUD operations for client entities (list, search, create, update, delete).
  - Provides scoped helpers (`list_clients_for_user/1`, `search_clients_for_user/2`) that respect RBAC.
  - Broadcasts PubSub events so LiveViews and background jobs can react to client changes.
  """
  import Ecto.Query, warn: false
  alias DashboardSSD.Clients.Client
  alias DashboardSSD.Repo
  alias Phoenix.PubSub

  @topic "clients"

  @doc """
  Subscribes the current process to client change notifications.

  Listen for PubSub broadcasts when clients are created, updated, or deleted.
  """
  @spec subscribe() :: :ok
  def subscribe do
    PubSub.subscribe(DashboardSSD.PubSub, @topic)
  end

  @doc """
  Lists all clients ordered by insertion time.

  Returns a list of Client structs.
  """
  @spec list_clients() :: [Client.t()]
  def list_clients, do: Repo.all(Client)

  @doc """
  Lists clients visible to the given user.

  Clients with the `client` role are limited to their assigned client (if any).
  Staff users (employees/admins) see all clients.
  """
  @spec list_clients_for_user(map() | nil) :: [Client.t()]
  def list_clients_for_user(nil), do: []

  def list_clients_for_user(%{role: %{name: "client"}, client_id: nil}), do: []

  def list_clients_for_user(%{role: %{name: "client"}, client_id: client_id})
      when is_integer(client_id),
      do: client_scope_query(client_id) |> Repo.all()

  def list_clients_for_user(_user), do: list_clients()

  @doc """
  Lists clients whose IDs are in the provided list.
  """
  @spec list_clients_by_ids([pos_integer()]) :: [Client.t()]
  def list_clients_by_ids([]), do: []

  def list_clients_by_ids(ids) when is_list(ids) do
    from(c in Client, where: c.id in ^ids) |> Repo.all()
  end

  @doc """
  Fetches a client by ID.

  Raises Ecto.NoResultsError if the client does not exist.
  """
  @spec get_client!(pos_integer()) :: Client.t()
  def get_client!(id), do: Repo.get!(Client, id)

  @doc """
  Returns a changeset for tracking client changes.

  Validates the given attributes against the client schema.
  """
  @spec change_client(Client.t(), map()) :: Ecto.Changeset.t()
  def change_client(%Client{} = client, attrs \\ %{}), do: Client.changeset(client, attrs)

  @doc """
  Creates a new client with the given attributes.

  Broadcasts a PubSub notification on successful creation.
  Returns {:ok, client} on success or {:error, changeset} on validation failure.
  """
  @spec create_client(map()) :: {:ok, Client.t()} | {:error, Ecto.Changeset.t()}
  def create_client(attrs) do
    %Client{}
    |> Client.changeset(attrs)
    |> Repo.insert()
    |> broadcast(:created)
  end

  @doc """
  Updates an existing client with the given attributes.

  Broadcasts a PubSub notification on successful update.
  Returns {:ok, client} on success or {:error, changeset} on validation failure.
  """
  @spec update_client(Client.t(), map()) :: {:ok, Client.t()} | {:error, Ecto.Changeset.t()}
  def update_client(%Client{} = client, attrs) do
    client
    |> Client.changeset(attrs)
    |> Repo.update()
    |> broadcast(:updated)
  end

  @doc """
  Deletes a client from the database.

  Broadcasts a PubSub notification on successful deletion.
  Returns {:ok, client} on success or {:error, changeset} on constraint violation.
  """
  @spec delete_client(Client.t()) :: {:ok, Client.t()} | {:error, Ecto.Changeset.t()}
  def delete_client(%Client{} = client) do
    client
    |> Repo.delete()
    |> broadcast(:deleted)
  end

  @doc """
  Searches clients by name using case-insensitive partial matching.

  Returns a list of matching Client structs.
  """
  @spec search_clients(String.t()) :: [Client.t()]
  def search_clients(term) when is_binary(term), do: scoped_search(Client, term)
  def search_clients(_), do: list_clients()

  @doc """
  Searches clients applying the current user's visibility scope.
  """
  @spec search_clients_for_user(map() | nil, term :: String.t()) :: [Client.t()]
  def search_clients_for_user(user, term \\ "")

  def search_clients_for_user(nil, _term), do: []

  def search_clients_for_user(%{role: %{name: "client"}, client_id: nil}, _term), do: []

  def search_clients_for_user(%{role: %{name: "client"}, client_id: client_id}, term)
      when is_integer(client_id),
      do: scoped_search(client_scope_query(client_id), term)

  def search_clients_for_user(_user, term), do: scoped_search(Client, term)

  @doc """
  Ensures a client with the given name exists.

  Creates the client if it doesn't exist, otherwise returns the existing one.
  """
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

  defp client_scope_query(client_id), do: from(c in Client, where: c.id == ^client_id)

  defp scoped_search(queryable, term) when term in [nil, ""],
    do: Repo.all(normalize_queryable(queryable))

  defp scoped_search(queryable, term) do
    like = "%" <> String.replace(term, "%", "\\%") <> "%"

    queryable
    |> normalize_queryable()
    |> where([c], ilike(c.name, ^like))
    |> Repo.all()
  end

  defp normalize_queryable(%Ecto.Query{} = query), do: query
  defp normalize_queryable(module) when is_atom(module), do: from(c in module)
end
