defmodule DashboardSSD.Integrations.DriveTest do
  use ExUnit.Case, async: true

  alias DashboardSSD.Integrations.Drive

  describe "list_files_in_folder/2" do
    test "includes auth header and q param" do
      Tesla.Mock.mock(fn
        %{
          method: :get,
          url: "https://www.googleapis.com/drive/v3/files",
          headers: headers,
          query: query
        } ->
          assert Enum.any?(headers, fn {k, v} ->
                   k == "authorization" and String.starts_with?(v, "Bearer ")
                 end)

          assert {:q, q} = Enum.find(query, fn {k, _} -> k == :q end)
          assert q =~ "in parents"
          %Tesla.Env{status: 200, body: %{"files" => []}}
      end)

      assert {:ok, %{"files" => []}} = Drive.list_files_in_folder("tok", "folder123")
    end

    test "returns http_error on non-200" do
      Tesla.Mock.mock(fn _ -> %Tesla.Env{status: 401, body: %{"error" => {"code", 401}}} end)
      assert {:error, {:http_error, 401, _}} = Drive.list_files_in_folder("bad", "folder123")
    end

    test "propagates adapter error tuple" do
      Tesla.Mock.mock(fn _ -> {:error, :timeout} end)
      assert {:error, :timeout} = Drive.list_files_in_folder("tok", "folder123")
    end
  end

  describe "ensure_project_folder/2" do
    test "returns existing folder when present" do
      Tesla.Mock.mock(fn
        %{method: :get, query: query} ->
          assert Enum.any?(query, fn {k, _} -> k == :q end)
          %Tesla.Env{status: 200, body: %{"files" => [%{"id" => "folder-1"}]}}
      end)

      assert {:ok, %{"id" => "folder-1"}} =
               Drive.ensure_project_folder("tok", %{parent_id: "parent", name: "Proj"})
    end

    test "creates folder when missing" do
      Tesla.Mock.mock(fn
        %{method: :get} ->
          %Tesla.Env{status: 200, body: %{"files" => []}}

        %{method: :post, body: body} ->
          body = Jason.decode!(body)
          assert body["name"] == "Proj"
          assert body["parents"] == ["parent"]
          assert body["appProperties"] == %{"project_id" => "42"}
          %Tesla.Env{status: 200, body: %{"id" => "new-folder"}}
      end)

      assert {:ok, %{"id" => "new-folder"}} =
               Drive.ensure_project_folder("tok", %{
                 parent_id: "parent",
                 name: "Proj",
                 properties: %{project_id: "42"}
               })
    end
  end

  describe "list_documents/1" do
    test "aggregates pages" do
      Tesla.Mock.mock(fn
        %{method: :get, query: query} ->
          case Keyword.get(query, :pageToken) do
            nil ->
              %Tesla.Env{
                status: 200,
                body: %{"files" => [%{"id" => "1"}], "nextPageToken" => "abc"}
              }

            "abc" ->
              %Tesla.Env{
                status: 200,
                body: %{"files" => [%{"id" => "2"}]}
              }
          end
      end)

      assert {:ok, %{"files" => [%{"id" => "1"}, %{"id" => "2"}]}} =
               Drive.list_documents(%{token: "tok", folder_id: "folder123"})
    end
  end

  describe "share_folder/3" do
    test "posts permission payload" do
      Tesla.Mock.mock(fn
        %{method: :post, url: url, body: body, query: query} ->
          body = Jason.decode!(body)
          assert url =~ "/files/folder123/permissions"
          assert body["role"] == "writer"
          assert body["type"] == "user"
          assert body["emailAddress"] == "user@example.com"
          assert {:sendNotificationEmail, false} in query
          %Tesla.Env{status: 200, body: %{"id" => "perm-1"}}
      end)

      assert {:ok, %{"id" => "perm-1"}} =
               Drive.share_folder("tok", "folder123", %{
                 role: "writer",
                 email: "user@example.com",
                 send_notification_email?: false
               })
    end
  end

  describe "unshare_folder/3" do
    test "removes permission entry" do
      Tesla.Mock.mock(fn
        %{method: :delete, url: url} ->
          assert url =~ "/files/folder123/permissions/perm-1"
          %Tesla.Env{status: 204, body: ""}
      end)

      assert :ok = Drive.unshare_folder("tok", "folder123", "perm-1")
    end
  end

  describe "download_file/2" do
    test "returns env on success" do
      Tesla.Mock.mock(fn
        %{method: :get, url: url, query: query} ->
          assert url =~ "/files/file-1"
          assert {:alt, "media"} in query
          %Tesla.Env{status: 200, body: "data", headers: [{"content-type", "application/pdf"}]}
      end)

      assert {:ok, %Tesla.Env{body: "data"}} = Drive.download_file("tok", "file-1")
    end
  end
end
