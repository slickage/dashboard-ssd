defmodule DashboardSSD.Clients do
  @moduledoc """
  Clients context: manage client records.
  """
  import Ecto.Query, warn: false
  alias DashboardSSD.Clients.Client
  alias DashboardSSD.Repo

  def list_clients, do: Repo.all(Client)
  def get_client!(id), do: Repo.get!(Client, id)
  def change_client(%Client{} = client, attrs \\ %{}), do: Client.changeset(client, attrs)

  def create_client(attrs) do
    %Client{} |> Client.changeset(attrs) |> Repo.insert()
  end

  def update_client(%Client{} = client, attrs) do
    client |> Client.changeset(attrs) |> Repo.update()
  end

  def delete_client(%Client{} = client) do
    Repo.delete(client)
  end
end
