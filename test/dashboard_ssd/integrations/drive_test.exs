defmodule DashboardSSD.Integrations.DriveTest do
  use ExUnit.Case, async: true

  alias DashboardSSD.Integrations.Drive

  setup do
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

        assert Enum.any?(query, fn {k, _v} -> k == :q end)
        %Tesla.Env{status: 200, body: %{"files" => []}}
    end)

    :ok
  end

  test "list_files_in_folder gets with q param and auth header" do
    assert {:ok, %{"files" => []}} = Drive.list_files_in_folder("tok", "folder123")
  end
end
