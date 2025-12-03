defmodule DashboardSSD.Projects.ProjectTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Projects.Project

  test "changeset validates presence of name" do
    refute Project.changeset(%Project{}, %{}).valid?
    assert Project.changeset(%Project{}, %{name: "Client Portal"}).valid?
  end

  test "drive_metadata_changeset requires inheritance flag when folder present" do
    project = %Project{drive_folder_sharing_inherited: nil}

    changeset =
      Project.drive_metadata_changeset(project, %{
        drive_folder_id: "folder-123"
      })

    assert %{drive_folder_sharing_inherited: ["can't be blank"]} = errors_on(changeset)

    assert %Ecto.Changeset{valid?: true} =
             Project.drive_metadata_changeset(project, %{
               drive_folder_id: "folder-123",
               drive_folder_sharing_inherited: false
             })
  end

  test "drive_metadata_changeset skips validation when folder id missing" do
    assert %Ecto.Changeset{valid?: true} =
             Project.drive_metadata_changeset(%Project{}, %{})
  end
end
