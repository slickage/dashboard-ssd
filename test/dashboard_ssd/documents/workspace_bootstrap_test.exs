defmodule DashboardSSD.Documents.WorkspaceBootstrapTest do
  use ExUnit.Case, async: false

  import Mox

  alias DashboardSSD.Documents.WorkspaceBootstrap
  alias DashboardSSD.Documents.WorkspaceBootstrap.DriveClientMock
  alias DashboardSSD.Documents.WorkspaceBootstrap.NotionClientMock
  alias DashboardSSD.Projects.Project

  defmodule InvalidDriveClient do
  end

  defmodule InvalidNotionClient do
  end

  defmodule CustomDriveClient do
    @behaviour DashboardSSD.Documents.WorkspaceBootstrap.DriveClient

    @impl true
    def ensure_section_folder(_project, _section, _opts) do
      send(self(), :custom_drive_folder)
      {:ok, %{id: "custom-folder"}}
    end

    @impl true
    def upsert_document(_project, section, _template, _opts) do
      send(self(), {:custom_drive_doc, section.id})
      {:ok, %{id: "custom-doc"}}
    end
  end

  defmodule CustomNotionClient do
    @behaviour DashboardSSD.Documents.WorkspaceBootstrap.NotionClient

    @impl true
    def upsert_page(_project, section, _template, _opts) do
      send(self(), {:custom_notion_page, section.id})
      {:ok, %{id: "custom-page"}}
    end
  end

  setup :set_mox_global
  setup :verify_on_exit!

  setup do
    original = Application.get_env(:dashboard_ssd, DashboardSSD.Documents.WorkspaceBlueprint)

    on_exit(fn ->
      Application.put_env(:dashboard_ssd, DashboardSSD.Documents.WorkspaceBlueprint, original)
    end)

    :ok
  end

  test "bootstraps selected drive and notion sections" do
    project = %Project{id: 1, name: "Client A", drive_folder_id: "drive123"}

    DriveClientMock
    |> expect(:ensure_section_folder, fn ^project, section, _opts ->
      assert section.id == :drive_contracts
      {:ok, %{id: "folder-contracts"}}
    end)
    |> expect(:upsert_document, fn ^project, section, template, _opts ->
      assert section.id == :drive_contracts
      assert template =~ "Service Agreement"
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

  test "returns error when sections override is invalid" do
    project = %Project{id: 5, name: "Client E", drive_folder_id: "folder-1"}

    assert {:error, {:invalid_sections, :all}} =
             WorkspaceBootstrap.bootstrap(project,
               sections: :all,
               drive_client: DriveClientMock,
               notion_client: NotionClientMock
             )
  end

  test "propagates template read failures" do
    project = %Project{id: 6, name: "Client F", drive_folder_id: "folder-2"}

    missing_path =
      Path.join(System.tmp_dir!(), "missing-template-#{System.unique_integer([:positive])}.md")

    Application.put_env(:dashboard_ssd, DashboardSSD.Documents.WorkspaceBlueprint, %{
      sections: [
        %{
          id: :drive_missing,
          type: :drive,
          template_path: missing_path
        }
      ],
      default_sections: [:drive_missing]
    })

    assert {:error, {:template_read_failed, ^missing_path, _reason}} =
             WorkspaceBootstrap.bootstrap(project,
               drive_client: DriveClientMock,
               notion_client: NotionClientMock
             )
  end

  test "uses default sections when override not provided" do
    project = %Project{id: 7, name: "Client G", drive_folder_id: "folder-3"}

    original =
      Application.get_env(:dashboard_ssd, DashboardSSD.Documents.WorkspaceBlueprint)
      |> Map.new()

    drive_section = Enum.find(original.sections, &(&1.id == :drive_contracts))
    notion_section = Enum.find(original.sections, &(&1.id == :notion_project_kb))

    Application.put_env(:dashboard_ssd, DashboardSSD.Documents.WorkspaceBlueprint, %{
      sections: [drive_section, notion_section],
      default_sections: [:drive_contracts, :notion_project_kb]
    })

    DriveClientMock
    |> expect(:ensure_section_folder, fn ^project, section, _opts ->
      assert section.id == :drive_contracts
      {:ok, %{id: "folder-contracts"}}
    end)
    |> expect(:upsert_document, fn ^project, section, template, _opts ->
      assert section.id == :drive_contracts
      assert template != ""
      {:ok, %{id: "doc-contracts"}}
    end)

    NotionClientMock
    |> expect(:upsert_page, fn ^project, section, template, _opts ->
      assert section.id == :notion_project_kb
      assert template != ""
      {:ok, %{id: "page-kb"}}
    end)

    assert {:ok, %{sections: results}} =
             WorkspaceBootstrap.bootstrap(project,
               drive_client: DriveClientMock,
               notion_client: NotionClientMock
             )

    assert Enum.map(results, & &1.section) == [:drive_contracts, :notion_project_kb]
  end

  test "raises when drive client does not implement behaviour" do
    project = %Project{id: 8, name: "Client H", drive_folder_id: "folder-4"}

    assert_raise ArgumentError, fn ->
      WorkspaceBootstrap.bootstrap(project,
        sections: [:drive_contracts],
        drive_client: InvalidDriveClient,
        notion_client: NotionClientMock
      )
    end
  end

  test "raises when notion client does not implement behaviour" do
    project = %Project{id: 9, name: "Client I", drive_folder_id: "folder-5"}

    assert_raise ArgumentError, fn ->
      WorkspaceBootstrap.bootstrap(project,
        sections: [:notion_project_kb],
        drive_client: DriveClientMock,
        notion_client: InvalidNotionClient
      )
    end
  end

  test "uses configured default clients" do
    project = %Project{id: 10, name: "Client Default", drive_folder_id: "folder-6"}

    Application.put_env(:dashboard_ssd, :workspace_bootstrap_drive_client, CustomDriveClient)
    Application.put_env(:dashboard_ssd, :workspace_bootstrap_notion_client, CustomNotionClient)

    on_exit(fn ->
      Application.delete_env(:dashboard_ssd, :workspace_bootstrap_drive_client)
      Application.delete_env(:dashboard_ssd, :workspace_bootstrap_notion_client)
    end)

    assert {:ok, %{sections: results}} =
             WorkspaceBootstrap.bootstrap(project,
               sections: [:drive_contracts, :notion_project_kb]
             )

    assert Enum.map(results, & &1.section) == [:drive_contracts, :notion_project_kb]
    assert_receive :custom_drive_folder
    assert_receive {:custom_drive_doc, :drive_contracts}
    assert_receive {:custom_notion_page, :notion_project_kb}
  end

  test "returns error when section provisioning fails" do
    project = %Project{id: 11, name: "Client J", drive_folder_id: "folder-7"}

    DriveClientMock
    |> expect(:ensure_section_folder, fn ^project, _section, _opts ->
      {:error, :api_failure}
    end)

    assert {:error, :api_failure} =
             WorkspaceBootstrap.bootstrap(project,
               sections: [:drive_contracts],
               drive_client: DriveClientMock,
               notion_client: NotionClientMock
             )
  end
end
