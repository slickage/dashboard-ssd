defmodule DashboardSSD.Documents.WorkspaceBootstrapTest do
  use ExUnit.Case, async: false

  import Mox

  alias DashboardSSD.Documents.WorkspaceBootstrap
  alias DashboardSSD.Documents.WorkspaceBootstrap.DriveClientMock
  alias DashboardSSD.Documents.WorkspaceBootstrap.NotionClientMock
  alias DashboardSSD.Projects.Project

  setup :set_mox_global
  setup :verify_on_exit!

  test "bootstraps selected drive and notion sections" do
    project = %Project{id: 1, name: "Client A", drive_folder_id: "drive123"}

    DriveClientMock
    |> expect(:ensure_section_folder, fn ^project, section, _opts ->
      assert section.id == :drive_contracts
      {:ok, %{id: "folder-contracts"}}
    end)
    |> expect(:upsert_document, fn ^project, section, template, _opts ->
      assert section.id == :drive_contracts
      assert template =~ "Contracts Workspace"
      {:ok, %{id: "doc-contracts"}}
    end)

    NotionClientMock
    |> expect(:upsert_page, fn ^project, section, template, _opts ->
      assert section.id == :notion_project_kb
      assert template =~ "Project Knowledge Base"
      {:ok, %{id: "page-kb"}}
    end)

    assert {:ok, %{sections: results}} =
             WorkspaceBootstrap.bootstrap(project,
               sections: [:drive_contracts, :notion_project_kb],
               drive_client: DriveClientMock,
               notion_client: NotionClientMock
             )

    assert Enum.find(results, &(&1.section == :drive_contracts))
    assert Enum.find(results, &(&1.section == :notion_project_kb))
  end

  test "returns error when drive folder missing" do
    project = %Project{id: 2, name: "Client B", drive_folder_id: nil}

    assert {:error, :project_drive_folder_missing} =
             WorkspaceBootstrap.bootstrap(project,
               sections: [:drive_contracts],
               drive_client: DriveClientMock,
               notion_client: NotionClientMock
             )
  end

  test "allows notion-only runs without drive metadata" do
    project = %Project{id: 3, name: "Client C", drive_folder_id: nil}

    expect(NotionClientMock, :upsert_page, fn ^project, section, template, _opts ->
      assert section.id == :notion_runbook
      assert template =~ "Project Runbook"
      {:ok, %{id: "page-runbook"}}
    end)

    assert {:ok, %{sections: [%{section: :notion_runbook}]}} =
             WorkspaceBootstrap.bootstrap(project,
               sections: [:notion_runbook],
               drive_client: DriveClientMock,
               notion_client: NotionClientMock
             )
  end

  test "blueprint errors when configuration missing" do
    original = Application.get_env(:dashboard_ssd, DashboardSSD.Documents.WorkspaceBlueprint)

    on_exit(fn ->
      Application.put_env(:dashboard_ssd, DashboardSSD.Documents.WorkspaceBlueprint, original)
    end)

    Application.delete_env(:dashboard_ssd, DashboardSSD.Documents.WorkspaceBlueprint)

    assert {:error, :workspace_blueprint_not_configured} = WorkspaceBootstrap.blueprint()
  end

  test "returns error for unknown section id" do
    project = %Project{id: 4, name: "Client D", drive_folder_id: "folder"}

    assert {:error, {:unknown_section, :bogus}} =
             WorkspaceBootstrap.bootstrap(project,
               sections: [:bogus],
               drive_client: DriveClientMock,
               notion_client: NotionClientMock
             )
  end
end
