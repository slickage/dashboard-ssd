defmodule DashboardSSD.Documents.WorkspaceBootstrap.GoogleDriveClientTest do
  use DashboardSSD.DataCase, async: true

  import ExUnit.CaptureLog

  alias DashboardSSD.Documents.WorkspaceBootstrap.GoogleDriveClient
  alias DashboardSSD.Projects.Project

  defmodule FakeDrive do
    def ensure_project_folder(_token, %{name: name}) do
      {:ok, %{"id" => "#{name}-folder"}}
    end

    def get_file(_token, folder_id) do
      meta =
        Process.get({:folder_meta, folder_id}, %{
          "driveId" => "drive-123",
          "id" => folder_id
        })

      {:ok, meta}
    end

    def find_file(_token, _folder_id, doc_name) do
      {:ok, Process.get({:existing_doc, doc_name})}
    end

    def create_doc_with_content(_token, parent_id, name, content) do
      send(Process.get(:test_pid), {:create_doc, parent_id, name, content})

      case Process.get(:create_doc_response) do
        {:error, reason} ->
          {:error, reason}

        {:ok, doc} ->
          {:ok, doc}

        nil ->
          id =
            if Process.get(:force_missing_doc_id) do
              nil
            else
              "doc-#{name}"
            end

          doc =
            %{"name" => name}
            |> put_id(id)

          {:ok, doc}
      end
    end

    defp put_id(doc, nil), do: doc
    defp put_id(doc, id), do: Map.put(doc, "id", id)

    def update_file_with_content(_token, doc_id, content) do
      send(Process.get(:test_pid), {:update_doc, doc_id, content})
      {:ok, %{"id" => doc_id, "name" => "updated"}}
    end
  end

  defmodule ErrorDrive do
    def ensure_project_folder(_token, _attrs), do: {:error, :quota}
  end

  setup do
    Application.put_env(:dashboard_ssd, :drive_api_module, FakeDrive)
    Process.put(:test_pid, self())

    on_exit(fn ->
      Application.delete_env(:dashboard_ssd, :drive_api_module)
      Process.delete(:test_pid)
      Process.delete({:existing_doc, "Drive · Contracts"})
      Process.delete({:folder_meta, "Drive · Contracts-folder"})
    end)

    :ok
  end

  defp project do
    %Project{id: 1, name: "Proj", drive_folder_id: "project-folder"}
  end

  defp section do
    %{id: :drive_contracts, label: "Drive · Contracts"}
  end

  describe "upsert_document/4" do
    test "creates document when missing" do
      Process.delete({:existing_doc, "Drive · Contracts"})

      assert {:ok, %{"webViewLink" => link}} =
               GoogleDriveClient.upsert_document(project(), section(), "# Hello", [])

      assert link == "https://docs.google.com/document/d/doc-Drive · Contracts/edit?usp=drivesdk"

      assert_receive {:create_doc, "Drive · Contracts-folder", "Drive · Contracts", "# Hello"}
      refute_received {:update_doc, _, _}
    end

    test "updates existing document" do
      Process.put({:existing_doc, "Drive · Contracts"}, %{"id" => "existing-doc"})

      assert {:ok, %{"webViewLink" => link}} =
               GoogleDriveClient.upsert_document(project(), section(), "Updated", [])

      assert link == "https://docs.google.com/document/d/existing-doc/edit?usp=drivesdk"

      assert_receive {:update_doc, "existing-doc", "Updated"}
      refute_received {:create_doc, _, _, _}
    end

    test "returns nil web view link when drive id missing" do
      Process.delete({:existing_doc, "Drive · Contracts"})

      Process.put({:folder_meta, "Drive · Contracts-folder"}, %{
        "id" => "Drive · Contracts-folder",
        "driveId" => nil
      })

      assert {:ok, %{"webViewLink" => nil}} =
               GoogleDriveClient.upsert_document(project(), section(), "Doc body", [])
    end

    test "returns error when section doc name cannot be derived" do
      section = %{folder_path: "Custom", id: "drive_contracts"}

      assert {:error, :invalid_section_name} =
               GoogleDriveClient.upsert_document(project(), section, "Body", [])
    end

    test "humanizes section id when no label present" do
      Process.delete({:existing_doc, "Drive · Contracts"})

      section = %{id: :drive_contracts}

      assert {:ok, _} =
               GoogleDriveClient.upsert_document(project(), section, "Body", [])

      assert_receive {:create_doc, _, "Drive Contracts", _}
    end

    test "returns nil web view link when created doc lacks id" do
      Process.delete({:existing_doc, "Drive · Contracts"})
      Process.put(:force_missing_doc_id, true)

      on_exit(fn -> Process.delete(:force_missing_doc_id) end)

      assert {:ok, %{"webViewLink" => nil}} =
               GoogleDriveClient.upsert_document(project(), section(), "Body", [])
    end

    test "propagates errors from create_doc_with_content" do
      Process.delete({:existing_doc, "Drive · Contracts"})
      Process.put(:create_doc_response, {:error, :quota})

      on_exit(fn -> Process.delete(:create_doc_response) end)

      assert {:error, :quota} =
               GoogleDriveClient.upsert_document(project(), section(), "Body", [])
    end
  end

  describe "ensure_section_folder/3" do
    test "returns folder metadata for humanized section name" do
      assert {:ok, %{"id" => "Drive Contracts-folder"}} =
               GoogleDriveClient.ensure_section_folder(
                 project(),
                 %{id: :drive_contracts},
                 []
               )
    end

    test "returns folder when explicit folder_path provided" do
      assert {:ok, %{"id" => "Special-folder"}} =
               GoogleDriveClient.ensure_section_folder(
                 project(),
                 %{folder_path: "Special"},
                 []
               )
    end

    test "errors when section metadata missing name" do
      assert {:error, :invalid_section_folder} =
               GoogleDriveClient.ensure_section_folder(project(), %{}, [])
    end
  end

  describe "error handling" do
    test "logs and returns errors from Drive API" do
      Application.put_env(:dashboard_ssd, :drive_api_module, ErrorDrive)
      Application.put_env(:dashboard_ssd, :integrations, drive_token: "drive-token")

      log =
        capture_log(fn ->
          assert {:error, :quota} =
                   GoogleDriveClient.upsert_document(project(), section(), "Body", [])
        end)

      assert log =~ "Drive bootstrap upsert failed"
    after
      Application.put_env(:dashboard_ssd, :drive_api_module, FakeDrive)
      Application.delete_env(:dashboard_ssd, :integrations)
    end
  end
end
