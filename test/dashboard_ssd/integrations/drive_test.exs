defmodule DashboardSSD.Integrations.DriveTest do
  use ExUnit.Case, async: true

  import Tesla.Mock

  alias DashboardSSD.Integrations.Drive

  @token "token"

  test "find_file returns file when present" do
    mock(fn
      %{method: :get, url: "https://www.googleapis.com/drive/v3/files"} ->
        %Tesla.Env{status: 200, body: %{"files" => [%{"id" => "file-1", "name" => "Doc"}]}}
    end)

    assert {:ok, %{"id" => "file-1"}} = Drive.find_file(@token, "folder", "Doc")
  end

  test "find_file returns nil when not found" do
    mock(fn
      %{method: :get, url: "https://www.googleapis.com/drive/v3/files"} ->
        %Tesla.Env{status: 200, body: %{"files" => []}}
    end)

    assert {:ok, nil} = Drive.find_file(@token, "folder", "Missing")
  end

  test "create_doc_with_content uploads markdown" do
    mock(fn
      %{method: :post, url: "https://www.googleapis.com/drive/v3/files"} ->
        %Tesla.Env{status: 200, body: %{"id" => "doc-1"}}

      %{method: :get, url: "https://docs.googleapis.com/v1/documents/doc-1"} ->
        %Tesla.Env{status: 200, body: %{"body" => %{"content" => [%{"endIndex" => 5}]}}}

      %{method: :post, url: "https://docs.googleapis.com/v1/documents/doc-1:batchUpdate"} ->
        %Tesla.Env{status: 200, body: %{"documentId" => "doc-1"}}
    end)

    assert {:ok, %{"id" => "doc-1"}} =
             Drive.create_doc_with_content(@token, "parent", "Doc", "# Title")
  end

  test "list_documents fetches multiple pages" do
    mock(fn
      %{method: :get, url: "https://www.googleapis.com/drive/v3/files", query: query} ->
        case Keyword.get(query, :pageToken) do
          nil ->
            %Tesla.Env{
              status: 200,
              body: %{"files" => [%{"id" => "file-1"}], "nextPageToken" => "next"}
            }

          "next" ->
            %Tesla.Env{status: 200, body: %{"files" => [%{"id" => "file-2"}]}}
        end
    end)

    assert {:ok, %{"files" => files}} =
             Drive.list_documents(%{token: @token, folder_id: "folder"})

    assert Enum.map(files, & &1["id"]) == ["file-1", "file-2"]
  end

  test "ensure_project_folder returns error on invalid args" do
    assert {:error, :invalid_folder_arguments} = Drive.ensure_project_folder(@token, %{})
  end

  test "share_folder sends permissions request" do
    mock(fn
      %{
        method: :post,
        url: "https://www.googleapis.com/drive/v3/files/folder-1/permissions",
        body: body,
        query: query
      } ->
        params = Jason.decode!(body)
        assert query[:supportsAllDrives]
        assert query[:sendNotificationEmail] == false
        assert params["role"] == "reader"
        assert params["emailAddress"] == "user@example.com"
        %Tesla.Env{status: 200, body: %{"id" => "perm-1"}}
    end)

    assert {:ok, %{"id" => "perm-1"}} =
             Drive.share_folder(@token, "folder-1", %{
               role: "reader",
               type: "user",
               email: "user@example.com"
             })
  end

  test "share_folder raises when email missing for user type" do
    assert_raise ArgumentError, fn ->
      Drive.share_folder(@token, "folder-1", %{role: "reader", type: "user"})
    end
  end

  test "unshare_folder returns :ok for 204" do
    mock(fn
      %{
        method: :delete,
        url: "https://www.googleapis.com/drive/v3/files/folder-1/permissions/perm-1",
        query: query
      } ->
        assert query[:supportsAllDrives]
        %Tesla.Env{status: 204, body: ""}
    end)

    assert :ok = Drive.unshare_folder(@token, "folder-1", "perm-1")
  end

  test "unshare_folder bubbles up errors" do
    mock(fn
      %{
        method: :delete,
        url: "https://www.googleapis.com/drive/v3/files/folder-1/permissions/perm-1",
        query: _
      } ->
        %Tesla.Env{status: 404, body: %{"error" => "notFound"}}
    end)

    assert {:error, {:http_error, 404, %{"error" => "notFound"}}} =
             Drive.unshare_folder(@token, "folder-1", "perm-1")
  end
end
