defmodule DashboardSSD.Documents.WorkspaceBootstrap.NotionProjectKBClientTest do
  use DashboardSSD.DataCase, async: false

  alias DashboardSSD.Clients.Client
  alias DashboardSSD.Documents.WorkspaceBootstrap.NotionProjectKBClient
  alias DashboardSSD.Documents.WorkspaceBootstrap.NotionProjectKBClientTest.NotionTestClient
  alias DashboardSSD.Projects.Project

  setup do
    {:ok, agent} =
      Agent.start_link(fn ->
        %{
          create_calls: [],
          delete_calls: [],
          append_calls: [],
          existing_client?: false,
          root_database_ids: []
        }
      end)

    Process.put(:notion_test_agent, agent)

    on_exit(fn ->
      if Process.alive?(agent), do: Agent.stop(agent)
      Process.delete(:notion_test_agent)
    end)

    %{agent: agent}
  end

  test "upsert_page builds the Notion hierarchy and updates the document content", %{agent: agent} do
    project = %Project{id: 123, name: "Phoenix Dashboard", client: %Client{name: "Slickage"}}

    template = """
    # Welcome
    ## Section
    - bullet
    > quote
    """

    opts = [
      notion_client: NotionTestClient,
      notion_token: "notion-token",
      projects_kb_parent_id: "root-db",
      notion_agent: agent
    ]

    assert {:ok, %{"id" => "doc-page"}} =
             NotionProjectKBClient.upsert_page(project, %{id: :contracts}, template, opts)

    state = Agent.get(agent, & &1)
    assert Enum.count(state.create_calls) == 3
    assert state.delete_calls == ["block-2", "block-1"]

    assert [{page_id, blocks}] = state.append_calls
    assert page_id == "doc-page"

    assert Enum.any?(blocks, fn block ->
             block["type"] in ["heading_1", "heading_2", "bulleted_list_item", "quote"]
           end)
  end

  test "upsert_page reuses existing client page and only creates project/doc entries", %{
    agent: agent
  } do
    project = %Project{id: 321, name: "Phoenix Dashboard", client: %Client{name: "Slickage"}}
    template = "# Hello"
    Agent.update(agent, &Map.put(&1, :existing_client?, true))

    opts = [
      notion_client: NotionTestClient,
      notion_token: "notion-token",
      projects_kb_parent_id: "root-db",
      notion_agent: agent,
      existing_client: true
    ]

    assert {:ok, %{"id" => "doc-page"}} =
             NotionProjectKBClient.upsert_page(project, %{id: :contracts}, template, opts)

    state = Agent.get(agent, & &1)
    assert Enum.count(state.create_calls) == 2
  end

  test "returns error when Notion database lookup fails", %{agent: agent} do
    Process.put(:notion_test_behavior, %{retrieve_database_error: {:error, :boom}})
    on_exit(fn -> Process.delete(:notion_test_behavior) end)

    project = %Project{id: 12, name: "Broken DB", client: %Client{name: "Slickage"}}

    opts = [
      notion_client: NotionTestClient,
      notion_token: "notion-token",
      projects_kb_parent_id: "root-db",
      notion_agent: agent
    ]

    assert {:error, error} =
             NotionProjectKBClient.upsert_page(project, %{id: :contracts}, "body", opts)

    assert error == :boom
  end

  test "returns error when Notion query fails", %{agent: agent} do
    Process.put(:notion_test_behavior, %{query_database_error: {:error, :boom}})
    on_exit(fn -> Process.delete(:notion_test_behavior) end)

    project = %Project{id: 13, name: "Broken Query", client: %Client{name: "Slickage"}}

    opts = [
      notion_client: NotionTestClient,
      notion_token: "notion-token",
      projects_kb_parent_id: "root-db",
      notion_agent: agent
    ]

    assert {:error, error} =
             NotionProjectKBClient.upsert_page(project, %{id: :contracts}, "body", opts)

    assert error == :boom
  end

  test "returns error when retrieving child pages fails", %{agent: agent} do
    Process.put(:notion_test_behavior, %{block_error_parent: "client-page"})
    on_exit(fn -> Process.delete(:notion_test_behavior) end)

    project = %Project{id: 14, name: "Broken Blocks", client: %Client{name: "Slickage"}}

    opts = [
      notion_client: NotionTestClient,
      notion_token: "notion-token",
      projects_kb_parent_id: "root-db",
      notion_agent: agent
    ]

    assert {:error, error} =
             NotionProjectKBClient.upsert_page(project, %{id: :contracts}, "body", opts)

    assert error == :boom
  end

  test "upsert_page fails when project is missing client" do
    project = %Project{id: 44, name: "Lonely Project", client: nil}

    assert {:error, :project_client_missing} =
             NotionProjectKBClient.upsert_page(project, %{id: :contracts}, "md", [])
  end

  test "upsert_page errors without a notion token" do
    project = %Project{id: 999, name: "Tokenless", client: %Client{name: "Slickage"}}

    original_shared = Application.get_env(:dashboard_ssd, :shared_documents_integrations)
    original_integrations = Application.get_env(:dashboard_ssd, :integrations)
    original_token = System.get_env("NOTION_TOKEN")
    original_api_key = System.get_env("NOTION_API_KEY")

    Application.delete_env(:dashboard_ssd, :shared_documents_integrations)
    Application.delete_env(:dashboard_ssd, :integrations)
    System.delete_env("NOTION_TOKEN")
    System.delete_env("NOTION_API_KEY")

    on_exit(fn ->
      if original_shared,
        do: Application.put_env(:dashboard_ssd, :shared_documents_integrations, original_shared)

      if original_integrations,
        do: Application.put_env(:dashboard_ssd, :integrations, original_integrations)

      if original_token, do: System.put_env("NOTION_TOKEN", original_token)
      if original_api_key, do: System.put_env("NOTION_API_KEY", original_api_key)
    end)

    assert {:error, {:missing_env, "NOTION_TOKEN"}} =
             NotionProjectKBClient.upsert_page(project, %{id: :contracts}, "foo", [])
  end

  test "uses shared notion config when root id not passed", %{agent: agent} do
    original_env = System.get_env("NOTION_PROJECTS_KB_PARENT_ID")
    System.delete_env("NOTION_PROJECTS_KB_PARENT_ID")

    Application.put_env(:dashboard_ssd, :shared_documents_integrations, %{
      notion: %{projects_kb_parent_id: "shared-root"}
    })

    on_exit(fn ->
      Application.delete_env(:dashboard_ssd, :shared_documents_integrations)
      if original_env, do: System.put_env("NOTION_PROJECTS_KB_PARENT_ID", original_env)
    end)

    project = %Project{id: 3210, name: "Shared Root", client: %Client{name: "Slickage"}}

    opts = [
      notion_client: NotionTestClient,
      notion_token: "notion-token",
      notion_agent: agent
    ]

    assert {:ok, _} =
             NotionProjectKBClient.upsert_page(project, %{id: :contracts}, "template", opts)

    state = Agent.get(agent, & &1)
    assert "shared-root" in state.root_database_ids
  end

  test "uses shared config token when no other token present", %{agent: agent} do
    original_shared = Application.get_env(:dashboard_ssd, :shared_documents_integrations)
    original_integrations = Application.get_env(:dashboard_ssd, :integrations)
    original_token = System.get_env("NOTION_TOKEN")
    original_api_key = System.get_env("NOTION_API_KEY")

    Application.delete_env(:dashboard_ssd, :integrations)
    System.delete_env("NOTION_TOKEN")
    System.delete_env("NOTION_API_KEY")

    Application.put_env(:dashboard_ssd, :shared_documents_integrations, %{
      notion: %{token: "shared-token"}
    })

    on_exit(fn ->
      if original_shared do
        Application.put_env(:dashboard_ssd, :shared_documents_integrations, original_shared)
      else
        Application.delete_env(:dashboard_ssd, :shared_documents_integrations)
      end

      if original_integrations,
        do: Application.put_env(:dashboard_ssd, :integrations, original_integrations)

      if original_token, do: System.put_env("NOTION_TOKEN", original_token)
      if original_api_key, do: System.put_env("NOTION_API_KEY", original_api_key)
    end)

    project = %Project{id: 222, name: "Shared Token", client: %Client{name: "Slickage"}}

    opts = [
      notion_client: NotionTestClient,
      projects_kb_parent_id: "root-db",
      notion_agent: agent
    ]

    assert {:ok, _} =
             NotionProjectKBClient.upsert_page(project, %{id: :contracts}, "template", opts)
  end

  test "uses integrations config token when provided", %{agent: agent} do
    original_shared = Application.get_env(:dashboard_ssd, :shared_documents_integrations)
    original_integrations = Application.get_env(:dashboard_ssd, :integrations)
    original_token = System.get_env("NOTION_TOKEN")
    original_api_key = System.get_env("NOTION_API_KEY")

    Application.delete_env(:dashboard_ssd, :shared_documents_integrations)
    System.delete_env("NOTION_TOKEN")
    System.delete_env("NOTION_API_KEY")
    Application.put_env(:dashboard_ssd, :integrations, notion_token: "integrations-token")

    on_exit(fn ->
      if original_shared,
        do: Application.put_env(:dashboard_ssd, :shared_documents_integrations, original_shared)

      if original_integrations,
        do: Application.put_env(:dashboard_ssd, :integrations, original_integrations)

      if original_token, do: System.put_env("NOTION_TOKEN", original_token)
      if original_api_key, do: System.put_env("NOTION_API_KEY", original_api_key)
    end)

    project = %Project{id: 333, name: "Integrations Token", client: %Client{name: "Slickage"}}

    opts = [
      notion_client: NotionTestClient,
      projects_kb_parent_id: "root-db",
      notion_agent: agent
    ]

    assert {:ok, _} =
             NotionProjectKBClient.upsert_page(project, %{id: :contracts}, "template", opts)
  end

  test "falls back to NOTION_API_KEY when tokens absent", %{agent: agent} do
    original_shared = Application.get_env(:dashboard_ssd, :shared_documents_integrations)
    original_integrations = Application.get_env(:dashboard_ssd, :integrations)
    original_token = System.get_env("NOTION_TOKEN")
    original_api_key = System.get_env("NOTION_API_KEY")

    Application.delete_env(:dashboard_ssd, :shared_documents_integrations)
    Application.delete_env(:dashboard_ssd, :integrations)
    System.delete_env("NOTION_TOKEN")
    System.put_env("NOTION_API_KEY", "api-key")

    on_exit(fn ->
      if original_shared,
        do: Application.put_env(:dashboard_ssd, :shared_documents_integrations, original_shared)

      if original_integrations,
        do: Application.put_env(:dashboard_ssd, :integrations, original_integrations)

      if original_token, do: System.put_env("NOTION_TOKEN", original_token)

      if original_api_key do
        System.put_env("NOTION_API_KEY", original_api_key)
      else
        System.delete_env("NOTION_API_KEY")
      end
    end)

    project = %Project{id: 444, name: "API Key", client: %Client{name: "Slickage"}}

    opts = [
      notion_client: NotionTestClient,
      projects_kb_parent_id: "root-db",
      notion_agent: agent
    ]

    assert {:ok, _} =
             NotionProjectKBClient.upsert_page(project, %{id: :contracts}, "template", opts)
  end
end

defmodule DashboardSSD.Documents.WorkspaceBootstrap.NotionProjectKBClientTest.NotionTestClient do
  def retrieve_database(_token, database_id, opts) do
    case test_behavior() do
      %{retrieve_database_error: error} ->
        error

      _ ->
        record(opts, :root_database_ids, database_id)
        {:ok, %{"id" => database_id}}
    end
  end

  def query_database(_, _, _opts) do
    agent = Process.get(:notion_test_agent)
    existing = agent && Agent.get(agent, & &1.existing_client?)

    case test_behavior() do
      %{query_database_error: error} ->
        error

      _ ->
        if existing do
          {:ok, %{"results" => [%{"id" => "client-page"}]}}
        else
          {:ok, %{"results" => []}}
        end
    end
  end

  def create_page(_token, %{parent: parent, properties: properties}, opts) do
    title = get_title(properties)
    record(opts, :create_calls, {parent, title})
    {:ok, %{"id" => page_id(title)}}
  end

  defp get_title(properties) do
    properties
    |> get_in(["Name", "title", Access.at(0), "text", "content"])
    |> then(fn
      nil -> get_in(properties, ["Name", "title", Access.at(0), "plain_text"])
      value -> value
    end)
  end

  def retrieve_block_children(_, parent_id, opts) do
    case test_behavior() do
      %{block_error_parent: parent} when parent == parent_id ->
        {:error, :boom}

      _ ->
        cursor = Keyword.get(opts, :start_cursor)

        case {parent_id, cursor} do
          {"client-page", nil} ->
            {:ok,
             %{
               "results" => [],
               "has_more" => true,
               "next_cursor" => "client-cursor"
             }}

          {"client-page", "client-cursor"} ->
            {:ok, %{"results" => []}}

          {"project-page", _} ->
            {:ok, %{"results" => []}}

          {"doc-page", nil} ->
            {:ok,
             %{
               "results" => [%{"id" => "block-1"}],
               "has_more" => true,
               "next_cursor" => "block-cursor"
             }}

          {"doc-page", "block-cursor"} ->
            {:ok, %{"results" => [%{"id" => "block-2"}]}}

          _ ->
            {:ok, %{"results" => []}}
        end
    end
  end

  def append_block_children(_token, page_id, blocks, opts) do
    record(opts, :append_calls, {page_id, blocks})
    {:ok, %{}}
  end

  def delete_block(_token, id, opts) do
    record(opts, :delete_calls, id)
    {:ok, %{}}
  end

  defp record(opts, key, value) do
    agent = notion_agent(opts)

    Agent.update(agent, fn state ->
      Map.update(state, key, [value], fn existing -> [value | existing] end)
    end)
  end

  defp notion_agent(opts) do
    Keyword.get(opts, :notion_agent) || Process.get(:notion_test_agent)
  end

  defp test_behavior do
    Process.get(:notion_test_behavior, %{})
  end

  defp page_id("Slickage"), do: "client-page"
  defp page_id("Phoenix Dashboard"), do: "project-page"
  defp page_id("Phoenix Dashboard Knowledge Base"), do: "doc-page"
  defp page_id(_), do: "doc-page"
end
