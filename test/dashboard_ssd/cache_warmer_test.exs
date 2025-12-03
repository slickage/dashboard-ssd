defmodule DashboardSSD.CacheWarmerTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  alias DashboardSSD.CacheWarmer

  defmodule StubCatalog do
    alias DashboardSSD.KnowledgeBase.Types.{DocumentDetail, DocumentSummary}

    def list_collections(_opts) do
      pid = lookup_pid()
      send(pid, {:stub, :list_collections})

      {:ok,
       %{
         collections: [
           %{
             id: "db-stub",
             name: "Stub",
             description: nil,
             icon: nil
           }
         ],
         errors: []
       }}
    end

    def list_documents(collection_id, _opts) do
      pid = lookup_pid()
      send(pid, {:stub, :list_documents, collection_id})

      {:ok,
       %{
         documents: [
           %DocumentSummary{
             id: doc_id(collection_id),
             collection_id: collection_id,
             title: "Stub Document #{collection_id}"
           }
         ],
         errors: []
       }}
    end

    def get_document(document_id, _opts) do
      pid = lookup_pid()
      send(pid, {:stub, :get_document, document_id})

      {:ok,
       %DocumentDetail{
         id: document_id,
         collection_id: detail_collection(document_id),
         title: "Stub Detail #{document_id}",
         rendered_blocks: []
       }}
    end

    defp doc_id(collection_id), do: "#{collection_id}:doc-1"

    defp detail_collection(document_id) do
      case String.split(document_id, ":", parts: 2) do
        [collection_id, _] -> collection_id
        [collection_id] -> collection_id
        _ -> "db-stub"
      end
    end

    defp lookup_pid do
      :persistent_term.get({__MODULE__, :pid})
    end
  end

  defmodule ErrorCatalog do
    def list_collections(_opts), do: {:error, :no_token}
  end

  defmodule RaisingCatalog do
    def list_collections(_opts), do: raise("boom")
  end

  defmodule NilIdCatalog do
    alias DashboardSSD.KnowledgeBase.Types.{DocumentDetail, DocumentSummary}

    def list_collections(_opts) do
      pid = lookup_pid()
      send(pid, {:nil_catalog, :list_collections})

      {:ok,
       %{
         collections: [
           %{id: nil},
           %{id: "db-real"}
         ],
         errors: []
       }}
    end

    def list_documents(collection_id, _opts) do
      pid = lookup_pid()
      send(pid, {:nil_catalog, :list_documents, collection_id})

      documents =
        case collection_id do
          nil ->
            []

          id ->
            [
              %DocumentSummary{
                id: "#{id}:doc-1",
                collection_id: id,
                title: "Nil Doc #{id}"
              }
            ]
        end

      {:ok, %{documents: documents, errors: []}}
    end

    def get_document(document_id, _opts) do
      pid = lookup_pid()
      send(pid, {:nil_catalog, :get_document, document_id})

      {:ok,
       %DocumentDetail{
         id: document_id,
         collection_id: detail_collection(document_id),
         title: "Nil Detail #{document_id}",
         rendered_blocks: []
       }}
    end

    defp detail_collection(document_id) do
      case String.split(document_id, ":", parts: 2) do
        [collection_id, _] -> collection_id
        [collection_id] -> collection_id
        _ -> "db-real"
      end
    end

    defp lookup_pid do
      :persistent_term.get({__MODULE__, :pid})
    end
  end

  defmodule StubProjects do
    def unique_linear_team_ids do
      pid = lookup_pid()
      send(pid, {:projects, :unique_ids})
      ["db-stub-team"]
    end

    def workflow_state_metadata_multi(ids) do
      pid = lookup_pid()
      send(pid, {:projects, :workflow_state_metadata_multi, ids})
      Enum.into(ids, %{}, &{&1, %{}})
    end

    def sync_from_linear(opts \\ []) do
      pid = lookup_pid()
      send(pid, {:projects, :sync_from_linear, opts})
      {:ok, %{cached?: true, synced_at: DateTime.utc_now(), summaries: %{}}}
    end

    defp lookup_pid do
      :persistent_term.get({__MODULE__, :pid})
    end
  end

  defmodule EmptyProjects do
    def unique_linear_team_ids, do: []
    def workflow_state_metadata_multi(_), do: %{}
    def sync_from_linear(_opts \\ []), do: {:ok, %{cached?: true, summaries: %{}}}
  end

  defmodule RaisingProjects do
    def unique_linear_team_ids, do: raise("boom")
    def sync_from_linear(_opts \\ []), do: raise("boom sync")
  end

  defmodule RateLimitedProjects do
    def unique_linear_team_ids, do: ["team-rate"]
    def workflow_state_metadata_multi(_), do: %{}
    def sync_from_linear(_opts \\ []), do: {:error, {:rate_limited, "temporary"}}
  end

  defmodule DetailErrorCatalog do
    alias DashboardSSD.KnowledgeBase.Types.{DocumentDetail, DocumentSummary}

    def list_collections(_opts) do
      pid = lookup_pid()
      send(pid, {:detail_error, :list_collections})

      {:ok,
       %{
         collections: [
           %{id: "db-error", name: "Error", description: nil, icon: nil}
         ],
         errors: []
       }}
    end

    def list_documents(collection_id, _opts) do
      pid = lookup_pid()
      send(pid, {:detail_error, :list_documents, collection_id})

      {:ok,
       %{
         documents: [
           %DocumentSummary{
             id: "#{collection_id}:doc-1",
             collection_id: collection_id,
             title: "Error Doc #{collection_id}"
           }
         ],
         errors: []
       }}
    end

    def get_document(document_id, _opts) do
      pid = lookup_pid()
      send(pid, {:detail_error, :get_document, document_id})
      {:error, :boom}
    end

    defp lookup_pid do
      :persistent_term.get({__MODULE__, :pid})
    end
  end

  defmodule ErrorDocumentsCatalog do
    def list_collections(_opts) do
      pid = lookup_pid()
      send(pid, {:doc_error, :list_collections})

      {:ok,
       %{
         collections: [
           %{id: "db-doc-error"}
         ],
         errors: []
       }}
    end

    def list_documents(collection_id, _opts) do
      pid = lookup_pid()
      send(pid, {:doc_error, :list_documents, collection_id})
      {:error, :timeout}
    end

    def get_document(_document_id, _opts), do: {:ok, :ignored}

    defp lookup_pid do
      :persistent_term.get({__MODULE__, :pid})
    end
  end

  defmodule RaisingDocumentsCatalog do
    def list_collections(_opts) do
      pid = lookup_pid()
      send(pid, {:doc_raise, :list_collections})

      {:ok,
       %{
         collections: [
           %{id: "db-doc-raise"}
         ],
         errors: []
       }}
    end

    def list_documents(collection_id, _opts) do
      pid = lookup_pid()
      send(pid, {:doc_raise, :list_documents, collection_id})
      raise "documents boom"
    end

    def get_document(_document_id, _opts), do: {:ok, :ignored}

    defp lookup_pid do
      :persistent_term.get({__MODULE__, :pid})
    end
  end

  defmodule RaisingDetailCatalog do
    alias DashboardSSD.KnowledgeBase.Types.DocumentSummary

    def list_collections(_opts) do
      pid = lookup_pid()
      send(pid, {:detail_raise, :list_collections})

      {:ok,
       %{
         collections: [
           %{id: "db-detail-raise"}
         ],
         errors: []
       }}
    end

    def list_documents(collection_id, _opts) do
      pid = lookup_pid()
      send(pid, {:detail_raise, :list_documents, collection_id})

      {:ok,
       %{
         documents: [
           %DocumentSummary{
             id: "#{collection_id}:doc-1",
             collection_id: collection_id,
             title: "Detail Raise #{collection_id}"
           }
         ],
         errors: []
       }}
    end

    def get_document(document_id, _opts) do
      pid = lookup_pid()
      send(pid, {:detail_raise, :get_document, document_id})
      raise "detail boom"
    end

    defp lookup_pid do
      :persistent_term.get({__MODULE__, :pid})
    end
  end

  defmodule MultiCollectionCatalog do
    alias DashboardSSD.KnowledgeBase.Types.{DocumentDetail, DocumentSummary}

    def list_collections(_opts) do
      pid = lookup_pid()
      send(pid, {:multi_catalog, :list_collections})

      {:ok,
       %{
         collections: [
           %{id: "db-empty"},
           %{id: "db-one"},
           %{id: "db-two"}
         ],
         errors: []
       }}
    end

    def list_documents("db-empty", _opts) do
      pid = lookup_pid()
      send(pid, {:multi_catalog, :list_documents, "db-empty"})
      {:ok, %{documents: [], errors: []}}
    end

    def list_documents(db_id, _opts) do
      pid = lookup_pid()
      send(pid, {:multi_catalog, :list_documents, db_id})

      {:ok,
       %{
         documents: [
           %DocumentSummary{
             id: "#{db_id}:doc-1",
             collection_id: db_id,
             title: "Doc #{db_id}"
           }
         ],
         errors: []
       }}
    end

    def get_document(document_id, _opts) do
      pid = lookup_pid()
      send(pid, {:multi_catalog, :get_document, document_id})

      {:ok,
       %DocumentDetail{
         id: document_id,
         collection_id: document_collection(document_id),
         title: "Detail #{document_id}",
         rendered_blocks: []
       }}
    end

    defp document_collection(document_id) do
      case String.split(document_id, ":", parts: 2) do
        [collection_id, _] -> collection_id
        [collection_id] -> collection_id
        _ -> nil
      end
    end

    defp lookup_pid do
      :persistent_term.get({__MODULE__, :pid})
    end
  end

  defmodule StringIdCatalog do
    alias DashboardSSD.KnowledgeBase.Types.DocumentDetail

    def list_collections(_opts) do
      pid = lookup_pid()
      send(pid, {:string_catalog, :list_collections})

      {:ok,
       %{
         collections: [
           %{
             "id" => "db-string",
             "name" => "String DB"
           }
         ],
         errors: []
       }}
    end

    def list_documents(collection_id, _opts) do
      pid = lookup_pid()
      send(pid, {:string_catalog, :list_documents, collection_id})

      {:ok,
       %{
         documents: [
           %{
             "id" => "doc-string",
             "collection_id" => collection_id,
             "title" => "String Document"
           }
         ],
         errors: []
       }}
    end

    def get_document(document_id, _opts) do
      pid = lookup_pid()
      send(pid, {:string_catalog, :get_document, document_id})

      {:ok,
       %DocumentDetail{
         id: document_id,
         collection_id: "db-string",
         title: "String Detail",
         rendered_blocks: []
       }}
    end

    defp lookup_pid do
      :persistent_term.get({__MODULE__, :pid})
    end
  end

  defmodule IntegerIdCatalog do
    alias DashboardSSD.KnowledgeBase.Types.DocumentDetail

    def list_collections(_opts) do
      pid = lookup_pid()
      send(pid, {:integer_catalog, :list_collections})

      {:ok,
       %{
         collections: [
           %{id: 123}
         ],
         errors: []
       }}
    end

    def list_documents(collection_id, _opts) do
      pid = lookup_pid()
      send(pid, {:integer_catalog, :list_documents, collection_id})

      {:ok,
       %{
         documents: [
           %{id: 456, title: "Integer Doc"}
         ],
         errors: []
       }}
    end

    def get_document(document_id, _opts) do
      pid = lookup_pid()
      send(pid, {:integer_catalog, :get_document, document_id})

      {:ok,
       %DocumentDetail{
         id: document_id,
         collection_id: "123",
         title: "Integer Detail #{document_id}",
         rendered_blocks: []
       }}
    end

    defp lookup_pid do
      :persistent_term.get({__MODULE__, :pid})
    end
  end

  defmodule WeirdCatalog do
    alias DashboardSSD.KnowledgeBase.Types.DocumentDetail

    def list_collections(_opts) do
      pid = lookup_pid()
      send(pid, {:weird_catalog, :list_collections})

      {:ok,
       %{
         collections: [
           nil,
           %{id: ""},
           %{id: {:tuple, 1}},
           %{id: :db_atom}
         ],
         errors: []
       }}
    end

    def list_documents(collection_id, _opts) do
      pid = lookup_pid()
      send(pid, {:weird_catalog, :list_documents, collection_id})

      {:ok,
       %{
         documents: [
           %{id: ""},
           %{id: :doc_atom},
           %{id: {:tuple, 2}},
           %{"id" => ""},
           %{"id" => "doc-string2"},
           "invalid"
         ],
         errors: []
       }}
    end

    def get_document(document_id, _opts) do
      pid = lookup_pid()
      send(pid, {:weird_catalog, :get_document, document_id})

      {:ok,
       %DocumentDetail{
         id: document_id,
         collection_id: "db_atom",
         title: "Weird Detail #{document_id}",
         rendered_blocks: []
       }}
    end

    defp lookup_pid do
      :persistent_term.get({__MODULE__, :pid})
    end
  end

  defmodule ErrorProjects do
    def unique_linear_team_ids, do: []
    def workflow_state_metadata_multi(_), do: %{}

    def sync_from_linear(_opts \\ []) do
      pid = lookup_pid()
      send(pid, {:projects, :sync_from_linear_error})
      {:error, :unexpected_failure}
    end

    defp lookup_pid do
      :persistent_term.get({__MODULE__, :pid})
    end
  end

  defmodule RaisingSyncProjects do
    def unique_linear_team_ids, do: []
    def workflow_state_metadata_multi(_), do: %{}

    def sync_from_linear(_opts \\ []) do
      pid = lookup_pid()
      send(pid, {:projects, :sync_from_linear_raise})
      raise "sync boom"
    end

    defp lookup_pid do
      :persistent_term.get({__MODULE__, :pid})
    end
  end

  setup do
    on_exit(fn ->
      :persistent_term.erase({StubCatalog, :pid})
      :persistent_term.erase({StubProjects, :pid})
      :persistent_term.erase({NilIdCatalog, :pid})
      :persistent_term.erase({ErrorProjects, :pid})
      :persistent_term.erase({RaisingSyncProjects, :pid})
      :persistent_term.erase({DetailErrorCatalog, :pid})
      :persistent_term.erase({ErrorDocumentsCatalog, :pid})
      :persistent_term.erase({RaisingDocumentsCatalog, :pid})
      :persistent_term.erase({RaisingDetailCatalog, :pid})
      :persistent_term.erase({StringIdCatalog, :pid})
      :persistent_term.erase({IntegerIdCatalog, :pid})
      :persistent_term.erase({WeirdCatalog, :pid})
      :persistent_term.erase({MultiCollectionCatalog, :pid})
    end)
  end

  test "warms collections and documents on schedule" do
    :persistent_term.put({StubCatalog, :pid}, self())
    :persistent_term.put({StubProjects, :pid}, self())

    start_supervised!(
      {CacheWarmer,
       catalog: StubCatalog,
       projects: StubProjects,
       notify: self(),
       initial_delay: 0,
       interval: :timer.hours(1)}
    )

    assert_receive {:stub, :list_collections}
    assert_receive {:stub, :list_documents, "db-stub"}
    assert_receive {:stub, :get_document, "db-stub:doc-1"}
    assert_receive {:cache_warmer, {:warmed, ["db-stub"]}}
    assert_receive {:projects, :unique_ids}
    assert_receive {:projects, :workflow_state_metadata_multi, ["db-stub-team"]}
    assert_receive {:projects, :sync_from_linear, []}
  end

  test "continues running when catalog returns error" do
    {:ok, pid} =
      start_supervised(
        {CacheWarmer,
         catalog: ErrorCatalog,
         projects: EmptyProjects,
         notify: self(),
         initial_delay: 0,
         interval: :timer.hours(1)}
      )

    # Allow warm cycle to run
    Process.sleep(50)
    assert Process.alive?(pid)

    refute_receive {:cache_warmer, _}
  end

  test "handles unexpected exceptions during warm" do
    {:ok, pid} =
      start_supervised(
        {CacheWarmer,
         catalog: RaisingCatalog,
         projects: EmptyProjects,
         notify: self(),
         initial_delay: 0,
         interval: :timer.hours(1)}
      )

    Process.sleep(50)
    assert Process.alive?(pid)
    refute_receive {:cache_warmer, _}
  end

  test "handles project warm failures" do
    :persistent_term.put({StubCatalog, :pid}, self())

    {:ok, pid} =
      start_supervised(
        {CacheWarmer,
         catalog: StubCatalog,
         projects: RaisingProjects,
         notify: self(),
         initial_delay: 0,
         interval: :timer.hours(1)}
      )

    Process.sleep(50)
    assert Process.alive?(pid)
    # catalog warm still runs despite project failure
    assert_receive {:stub, :list_collections}
    assert_receive {:stub, :list_documents, "db-stub"}
    assert_receive {:stub, :get_document, "db-stub:doc-1"}
    refute_received {:projects, :sync_from_linear, _}
  end

  test "skips collections without identifiers" do
    :persistent_term.put({NilIdCatalog, :pid}, self())
    :persistent_term.put({StubProjects, :pid}, self())

    start_supervised!(
      {CacheWarmer,
       catalog: NilIdCatalog,
       projects: StubProjects,
       notify: self(),
       initial_delay: 0,
       interval: :timer.hours(1)}
    )

    assert_receive {:nil_catalog, :list_collections}
    assert_receive {:nil_catalog, :list_documents, "db-real"}
    assert_receive {:nil_catalog, :get_document, "db-real:doc-1"}
    refute_received {:nil_catalog, :list_documents, nil}
    assert_receive {:projects, :unique_ids}
    assert_receive {:projects, :workflow_state_metadata_multi, ["db-stub-team"]}
    assert_receive {:projects, :sync_from_linear, []}
  end

  test "honors positive initial delay" do
    :persistent_term.put({StubCatalog, :pid}, self())
    :persistent_term.put({StubProjects, :pid}, self())

    start_supervised!(
      {CacheWarmer,
       catalog: StubCatalog,
       projects: StubProjects,
       notify: self(),
       initial_delay: 50,
       interval: :timer.hours(1)}
    )

    refute_receive {:stub, :list_collections}, 20
    Process.sleep(60)
    assert_receive {:stub, :list_collections}
    assert_receive {:stub, :list_documents, "db-stub"}
    assert_receive {:stub, :get_document, "db-stub:doc-1"}
    assert_receive {:projects, :unique_ids}
    assert_receive {:projects, :workflow_state_metadata_multi, ["db-stub-team"]}
    assert_receive {:projects, :sync_from_linear, []}
  end

  test "does not emit notifications when notify option is omitted" do
    :persistent_term.put({StubCatalog, :pid}, self())
    :persistent_term.put({StubProjects, :pid}, self())

    start_supervised!(
      {CacheWarmer,
       catalog: StubCatalog, projects: StubProjects, initial_delay: 0, interval: :timer.hours(1)}
    )

    assert_receive {:stub, :list_collections}
    assert_receive {:stub, :list_documents, "db-stub"}
    assert_receive {:stub, :get_document, "db-stub:doc-1"}
    refute_receive {:cache_warmer, _}
    assert_receive {:projects, :unique_ids}
    assert_receive {:projects, :workflow_state_metadata_multi, ["db-stub-team"]}
  end

  test "handles linear summary rate-limit responses gracefully" do
    :persistent_term.put({StubCatalog, :pid}, self())

    start_supervised!(
      {CacheWarmer,
       catalog: StubCatalog,
       projects: RateLimitedProjects,
       notify: self(),
       initial_delay: 0,
       interval: :timer.hours(1)}
    )

    assert_receive {:stub, :list_collections}
    assert_receive {:stub, :list_documents, "db-stub"}
    assert_receive {:stub, :get_document, "db-stub:doc-1"}
  end

  test "logs and continues on unexpected linear sync errors" do
    :persistent_term.put({StubCatalog, :pid}, self())
    :persistent_term.put({ErrorProjects, :pid}, self())

    start_supervised!(
      {CacheWarmer,
       catalog: StubCatalog,
       projects: ErrorProjects,
       notify: self(),
       initial_delay: 0,
       interval: :timer.hours(1)}
    )

    assert_receive {:stub, :list_collections}
    assert_receive {:stub, :list_documents, "db-stub"}
    assert_receive {:stub, :get_document, "db-stub:doc-1"}
    assert_receive {:projects, :sync_from_linear_error}
  end

  test "handles raised exceptions during linear sync warm" do
    :persistent_term.put({StubCatalog, :pid}, self())
    :persistent_term.put({RaisingSyncProjects, :pid}, self())

    {:ok, pid} =
      start_supervised(
        {CacheWarmer,
         catalog: StubCatalog,
         projects: RaisingSyncProjects,
         notify: self(),
         initial_delay: 0,
         interval: :timer.hours(1)}
      )

    assert_receive {:stub, :list_collections}
    assert_receive {:stub, :list_documents, "db-stub"}
    assert_receive {:stub, :get_document, "db-stub:doc-1"}
    assert_receive {:projects, :sync_from_linear_raise}
    assert Process.alive?(pid)
  end

  test "continues when initial document detail warm errors" do
    :persistent_term.put({DetailErrorCatalog, :pid}, self())

    {:ok, pid} =
      start_supervised(
        {CacheWarmer,
         catalog: DetailErrorCatalog,
         projects: EmptyProjects,
         notify: self(),
         initial_delay: 0,
         interval: :timer.hours(1)}
      )

    assert_receive {:detail_error, :list_collections}
    assert_receive {:detail_error, :list_documents, "db-error"}
    assert_receive {:detail_error, :get_document, "db-error:doc-1"}
    Process.sleep(20)
    assert Process.alive?(pid)
  end

  test "handles document list errors gracefully" do
    :persistent_term.put({ErrorDocumentsCatalog, :pid}, self())

    {:ok, pid} =
      start_supervised(
        {CacheWarmer,
         catalog: ErrorDocumentsCatalog,
         projects: EmptyProjects,
         notify: self(),
         initial_delay: 0,
         interval: :timer.hours(1)}
      )

    assert_receive {:doc_error, :list_collections}
    assert_receive {:doc_error, :list_documents, "db-doc-error"}
    Process.sleep(20)
    assert Process.alive?(pid)
  end

  test "handles document list exceptions gracefully" do
    :persistent_term.put({RaisingDocumentsCatalog, :pid}, self())

    {:ok, pid} =
      start_supervised(
        {CacheWarmer,
         catalog: RaisingDocumentsCatalog,
         projects: EmptyProjects,
         notify: self(),
         initial_delay: 0,
         interval: :timer.hours(1)}
      )

    assert_receive {:doc_raise, :list_collections}
    assert_receive {:doc_raise, :list_documents, "db-doc-raise"}
    Process.sleep(20)
    assert Process.alive?(pid)
  end

  test "handles document detail raises gracefully" do
    :persistent_term.put({RaisingDetailCatalog, :pid}, self())

    {:ok, pid} =
      start_supervised(
        {CacheWarmer,
         catalog: RaisingDetailCatalog,
         projects: EmptyProjects,
         notify: self(),
         initial_delay: 0,
         interval: :timer.hours(1)}
      )

    assert_receive {:detail_raise, :list_collections}
    assert_receive {:detail_raise, :list_documents, "db-detail-raise"}
    assert_receive {:detail_raise, :get_document, "db-detail-raise:doc-1"}
    Process.sleep(20)
    assert Process.alive?(pid)
  end

  test "supports string keyed catalog data" do
    :persistent_term.put({StringIdCatalog, :pid}, self())

    start_supervised!(
      {CacheWarmer,
       catalog: StringIdCatalog,
       projects: EmptyProjects,
       notify: self(),
       initial_delay: 0,
       interval: :timer.hours(1)}
    )

    assert_receive {:string_catalog, :list_collections}
    assert_receive {:string_catalog, :list_documents, "db-string"}
    assert_receive {:string_catalog, :get_document, "doc-string"}
  end

  test "normalizes numeric identifiers" do
    :persistent_term.put({IntegerIdCatalog, :pid}, self())

    start_supervised!(
      {CacheWarmer,
       catalog: IntegerIdCatalog,
       projects: EmptyProjects,
       notify: self(),
       initial_delay: 0,
       interval: :timer.hours(1)}
    )

    assert_receive {:integer_catalog, :list_collections}
    assert_receive {:integer_catalog, :list_documents, "123"}
    assert_receive {:integer_catalog, :get_document, "456"}
  end

  test "warms first document detail only once when multiple collections present" do
    :persistent_term.put({MultiCollectionCatalog, :pid}, self())
    :persistent_term.put({StubProjects, :pid}, self())

    start_supervised!(
      {CacheWarmer,
       catalog: MultiCollectionCatalog,
       projects: StubProjects,
       notify: self(),
       initial_delay: 0,
       interval: :timer.hours(1)}
    )

    assert_receive {:multi_catalog, :list_collections}
    assert_receive {:multi_catalog, :list_documents, "db-empty"}
    assert_receive {:multi_catalog, :list_documents, "db-one"}
    assert_receive {:multi_catalog, :get_document, "db-one:doc-1"}
    refute_receive {:multi_catalog, :get_document, _}, 20
    assert_receive {:multi_catalog, :list_documents, "db-two"}
    assert_receive {:cache_warmer, {:warmed, warmed_ids}}
    assert warmed_ids == ["db-empty", "db-one", "db-two"]
  end

  test "handles mixed identifier formats gracefully" do
    :persistent_term.put({WeirdCatalog, :pid}, self())

    start_supervised!(
      {CacheWarmer,
       catalog: WeirdCatalog,
       projects: EmptyProjects,
       notify: self(),
       initial_delay: 0,
       interval: :timer.hours(1)}
    )

    assert_receive {:weird_catalog, :list_collections}
    # first valid collection id should normalize to "db_atom"
    assert_receive {:weird_catalog, :list_documents, "db_atom"}
    assert_receive {:weird_catalog, :get_document, "doc_atom"}
  end

  describe "logger debug coverage" do
    test "covers logger debug in rescues" do
      capture_log(fn ->
        Logger.configure(level: :debug)
        on_exit(fn -> Logger.configure(level: :warning) end)

        # trigger warm_collections rescue
        :persistent_term.put({RaisingCatalog, :pid}, self())

        {:ok, pid1} =
          GenServer.start_link(CacheWarmer,
            catalog: RaisingCatalog,
            projects: EmptyProjects,
            initial_delay: 0,
            interval: :timer.hours(1)
          )

        Process.sleep(50)
        GenServer.stop(pid1)

        # trigger warm_workflow_states rescue
        :persistent_term.put({RaisingProjects, :pid}, self())

        {:ok, pid2} =
          GenServer.start_link(CacheWarmer,
            catalog: RaisingProjects,
            projects: RaisingProjects,
            initial_delay: 0,
            interval: :timer.hours(1)
          )

        Process.sleep(50)
        GenServer.stop(pid2)

        # trigger safe_sync_projects rescue
        :persistent_term.put({RaisingSyncProjects, :pid}, self())

        {:ok, pid3} =
          GenServer.start_link(CacheWarmer,
            catalog: StubCatalog,
            projects: RaisingSyncProjects,
            initial_delay: 0,
            interval: :timer.hours(1)
          )

        Process.sleep(50)
        GenServer.stop(pid3)

        # trigger list_collection_documents rescue
        :persistent_term.put({RaisingDocumentsCatalog, :pid}, self())

        {:ok, pid4} =
          GenServer.start_link(CacheWarmer,
            catalog: RaisingDocumentsCatalog,
            projects: EmptyProjects,
            initial_delay: 0,
            interval: :timer.hours(1)
          )

        Process.sleep(50)
        GenServer.stop(pid4)

        # trigger warm_initial_document rescue
        :persistent_term.put({RaisingDetailCatalog, :pid}, self())

        {:ok, pid5} =
          GenServer.start_link(CacheWarmer,
            catalog: RaisingDetailCatalog,
            projects: EmptyProjects,
            initial_delay: 0,
            interval: :timer.hours(1)
          )

        Process.sleep(50)
        GenServer.stop(pid5)
      end)
    end
  end
end
