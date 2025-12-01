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

  test "ensure_project_folder reuses existing folder" do
    mock(fn
      %{method: :get, url: "https://www.googleapis.com/drive/v3/files", query: query} ->
        assert String.contains?(Keyword.get(query, :q), "mimeType")
        {:ok, %Tesla.Env{status: 200, body: %{"files" => [%{"id" => "existing"}]}}}
    end)

    assert {:ok, %{"id" => "existing"}} =
             Drive.ensure_project_folder(@token, %{parent_id: "parent", name: "Contracts"})
  end

  test "ensure_project_folder creates folder when missing" do
    mock(fn
      %{method: :get, url: "https://www.googleapis.com/drive/v3/files", query: query} ->
        assert String.contains?(Keyword.get(query, :q), "mimeType")
        {:ok, %Tesla.Env{status: 200, body: %{"files" => []}}}

      %{method: :post, url: "https://www.googleapis.com/drive/v3/files", body: body} ->
        params = Jason.decode!(body)
        assert params["mimeType"] =~ "folder"
        {:ok, %Tesla.Env{status: 200, body: %{"id" => "new-folder"}}}
    end)

    assert {:ok, %{"id" => "new-folder"}} =
             Drive.ensure_project_folder(@token, %{
               parent_id: "parent",
               name: "Contracts",
               description: "Docs"
             })
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

  test "create_doc_with_content propagates Docs API errors" do
    mock(fn
      %{method: :post, url: "https://www.googleapis.com/drive/v3/files"} ->
        %Tesla.Env{status: 200, body: %{"id" => "doc-error"}}

      %{method: :get, url: "https://docs.googleapis.com/v1/documents/doc-error"} ->
        {:ok, %Tesla.Env{status: 404, body: %{"error" => "missing"}}}
    end)

    assert {:error, {:http_error, 404, %{"error" => "missing"}}} =
             Drive.create_doc_with_content(@token, "parent", "Doc", "## Body")
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

  test "list_documents bubbles up api errors" do
    mock(fn
      %{method: :get, url: "https://www.googleapis.com/drive/v3/files"} ->
        {:ok, %Tesla.Env{status: 500, body: %{"error" => "boom"}}}
    end)

    assert {:error, {:http_error, 500, %{"error" => "boom"}}} =
             Drive.list_documents(%{token: @token, folder_id: "folder"})
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

  test "download_file returns error on non-success responses" do
    mock(fn
      %{method: :get, url: "https://www.googleapis.com/drive/v3/files/file-err"} ->
        {:ok, %Tesla.Env{status: 404, body: %{"error" => "missing"}}}
    end)

    assert {:error, {:http_error, 404, %{"error" => "missing"}}} =
             Drive.download_file(@token, "file-err")
  end

  test "download_file returns env on success" do
    mock(fn
      %{method: :get, url: "https://www.googleapis.com/drive/v3/files/file-ok", query: query} ->
        assert query[:alt] == "media"
        {:ok, %Tesla.Env{status: 200, body: "content"}}
    end)

    assert {:ok, %Tesla.Env{body: "content"}} = Drive.download_file(@token, "file-ok")
  end

  test "get_file returns metadata for success" do
    mock(fn
      %{method: :get, url: "https://www.googleapis.com/drive/v3/files/meta-1", query: query} ->
        assert query[:supportsAllDrives]
        {:ok, %Tesla.Env{status: 200, body: %{"id" => "meta-1"}}}
    end)

    assert {:ok, %{"id" => "meta-1"}} = Drive.get_file(@token, "meta-1")
  end

  test "get_file returns error when API fails" do
    mock(fn
      %{method: :get, url: "https://www.googleapis.com/drive/v3/files/meta-error"} ->
        {:ok, %Tesla.Env{status: 500, body: %{"error" => "boom"}}}
    end)

    assert {:error, {:http_error, 500, %{"error" => "boom"}}} =
             Drive.get_file(@token, "meta-error")
  end

  test "list_documents validates folder id" do
    assert {:error, :invalid_arguments} = Drive.list_documents(%{token: @token, folder_id: ""})
  end

  describe "Docs API updates" do
    test "update_file_with_content clears old body and applies heading styles" do
      mock(fn
        %{method: :get, url: "https://docs.googleapis.com/v1/documents/doc-2"} ->
          {:ok,
           %Tesla.Env{
             status: 200,
             body: %{"body" => %{"content" => [%{"endIndex" => 12}]}}
           }}

        %{
          method: :post,
          url: "https://docs.googleapis.com/v1/documents/doc-2:batchUpdate",
          body: body
        } ->
          payload = Jason.decode!(body)
          assert Enum.find(payload["requests"], &Map.has_key?(&1, "deleteContentRange"))

          insert = Enum.find(payload["requests"], &Map.has_key?(&1, "insertText"))
          assert insert["insertText"]["text"] =~ "Plan"
          assert insert["insertText"]["text"] =~ "\n• Item"

          style =
            Enum.find(payload["requests"], fn req ->
              Map.has_key?(req, "updateParagraphStyle")
            end)

          assert style["updateParagraphStyle"]["paragraphStyle"]["namedStyleType"] == "HEADING_1"

          {:ok, %Tesla.Env{status: 200, body: %{"documentId" => "doc-2"}}}
      end)

      content = """
      # Project Plan
      - Item
      """

      assert {:ok, %{"id" => "doc-2"}} =
               Drive.update_file_with_content(@token, "doc-2", content)
    end

    test "update_file_with_content skips delete when doc empty" do
      mock(fn
        %{method: :get, url: "https://docs.googleapis.com/v1/documents/doc-empty"} ->
          {:ok,
           %Tesla.Env{
             status: 200,
             body: %{"body" => %{"content" => [%{}]}}
           }}

        %{
          method: :post,
          url: "https://docs.googleapis.com/v1/documents/doc-empty:batchUpdate",
          body: body
        } ->
          payload = Jason.decode!(body)
          refute Enum.any?(payload["requests"], &Map.has_key?(&1, "deleteContentRange"))
          {:ok, %Tesla.Env{status: 200, body: %{"documentId" => "doc-empty"}}}
      end)

      assert {:ok, %{"id" => "doc-empty"}} =
               Drive.update_file_with_content(@token, "doc-empty", "Body")
    end

    test "update_file_with_content returns error when doc metadata fails" do
      mock(fn
        %{method: :get, url: "https://docs.googleapis.com/v1/documents/doc-bad"} ->
          {:ok, %Tesla.Env{status: 403, body: %{"error" => "denied"}}}
      end)

      assert {:error, {:http_error, 403, %{"error" => "denied"}}} =
               Drive.update_file_with_content(@token, "doc-bad", "Body")
    end
  end
end
