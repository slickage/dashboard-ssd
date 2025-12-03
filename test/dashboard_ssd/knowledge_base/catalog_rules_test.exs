defmodule DashboardSSD.KnowledgeBase.CatalogRulesTest do
  use ExUnit.Case, async: true

  alias DashboardSSD.KnowledgeBase.Catalog

  setup do
    prev_kb = Application.get_env(:dashboard_ssd, DashboardSSD.KnowledgeBase)

    on_exit(fn ->
      case prev_kb do
        nil -> Application.delete_env(:dashboard_ssd, DashboardSSD.KnowledgeBase)
        v -> Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase, v)
      end
    end)

    :ok
  end

  defp page_with_db(db_id, props \\ %{}) do
    %{
      "id" => "page-1",
      "parent" => %{"type" => "database_id", "database_id" => db_id},
      "properties" => props
    }
  end

  test "skip document type filter for exempt database" do
    Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
      document_type_filter_exempt_ids: ["db_exempt"]
    )

    page = page_with_db("db_exempt")
    assert Catalog.allowed_document?(page) == true
  end

  test "allowed when allowed types list is empty" do
    Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
      allowed_document_type_values: [],
      document_type_property_names: []
    )

    page = page_with_db("db1", %{"Type" => %{}})
    assert Catalog.allowed_document?(page) == true
  end

  test "no type present respects allow_documents_without_type? flag" do
    # Disallow when missing types
    Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
      allowed_document_type_values: ["guide"],
      document_type_property_names: ["Type"],
      allow_documents_without_type?: false
    )

    page = page_with_db("db1", %{"Other" => %{}})
    assert Catalog.allowed_document?(page) == false

    # Allow when flag true
    Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
      allowed_document_type_values: ["guide"],
      document_type_property_names: ["Type"],
      allow_documents_without_type?: true
    )

    assert Catalog.allowed_document?(page) == true
  end

  test "select/status/multi_select property values are normalized and matched" do
    Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
      allowed_document_type_values: ["guide", "in_progress", "tag-a"],
      document_type_property_names: []
    )

    page =
      page_with_db(
        "db1",
        %{
          "Type" => %{"type" => "select", "select" => %{"name" => "Guide"}},
          "Status" => %{"type" => "status", "status" => %{"name" => "In Progress"}},
          "Tags" => %{"type" => "multi_select", "multi_select" => [%{"name" => "Tag-A"}]}
        }
      )

    assert Catalog.allowed_document?(page) == true
  end

  test "disallowed when types present but not in allowed set" do
    Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase,
      allowed_document_type_values: ["allowed"],
      document_type_property_names: []
    )

    page =
      page_with_db("db1", %{"Type" => %{"type" => "select", "select" => %{"name" => "Other"}}})

    assert Catalog.allowed_document?(page) == false
  end
end
