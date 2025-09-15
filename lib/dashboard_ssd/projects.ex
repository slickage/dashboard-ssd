defmodule DashboardSSD.Projects do
  @moduledoc """
  Projects context: manage projects and queries per client.
  """
  import Ecto.Query, warn: false
  alias DashboardSSD.Projects.Project
  alias DashboardSSD.Repo

  @doc "List all projects"
  @spec list_projects() :: [Project.t()]
  def list_projects, do: Repo.all(Project)

  @doc "List projects for a given client id"
  @spec list_projects_by_client(pos_integer()) :: [Project.t()]
  def list_projects_by_client(client_id) do
    from(p in Project, where: p.client_id == ^client_id) |> Repo.all()
  end

  @doc "Fetch a project by id, raising if not found"
  @spec get_project!(pos_integer()) :: Project.t()
  def get_project!(id), do: Repo.get!(Project, id)

  @doc "Return a changeset for a project with proposed changes"
  @spec change_project(Project.t(), map()) :: Ecto.Changeset.t()
  def change_project(%Project{} = project, attrs \\ %{}), do: Project.changeset(project, attrs)

  @doc "Create a new project"
  @spec create_project(map()) :: {:ok, Project.t()} | {:error, Ecto.Changeset.t()}
  def create_project(attrs) do
    %Project{} |> Project.changeset(attrs) |> Repo.insert()
  end

  @doc "Update an existing project"
  @spec update_project(Project.t(), map()) :: {:ok, Project.t()} | {:error, Ecto.Changeset.t()}
  def update_project(%Project{} = project, attrs) do
    project |> Project.changeset(attrs) |> Repo.update()
  end

  @doc "Delete a project"
  @spec delete_project(Project.t()) :: {:ok, Project.t()} | {:error, Ecto.Changeset.t()}
  def delete_project(%Project{} = project) do
    Repo.delete(project)
  end
end
