defmodule DashboardSSDWeb.KbLive.IndexUnitTest do
  use DashboardSSDWeb.ConnCase, async: true

  alias DashboardSSDWeb.KbLive.Index, as: KbIndexLive

  describe "handle_event helpers" do
    test "typeahead_search trims blank input" do
      socket =
        kb_socket(%{
          query: "Docs",
          results: [%{id: "1"}],
          search_performed: true,
          search_dropdown_open: true
        })

      {:noreply, updated} =
        KbIndexLive.handle_event("typeahead_search", %{"query" => "   "}, socket)

      assert updated.assigns.query == ""
      assert updated.assigns.results == []
      refute updated.assigns.search_performed
      refute updated.assigns.search_dropdown_open
    end

    test "typeahead_search surfaces missing Notion configuration" do
      original_integrations = Application.get_env(:dashboard_ssd, :integrations)
      System.delete_env("NOTION_TOKEN")
      System.delete_env("NOTION_API_KEY")
      Application.delete_env(:dashboard_ssd, :integrations)

      on_exit(fn ->
        if original_integrations do
          Application.put_env(:dashboard_ssd, :integrations, original_integrations)
        else
          Application.delete_env(:dashboard_ssd, :integrations)
        end
      end)

      socket = kb_socket(%{})

      {:noreply, updated} =
        KbIndexLive.handle_event("typeahead_search", %{"query" => "Docs"}, socket)

      assert updated.assigns.results == []
      assert updated.assigns.search_performed
      assert updated.assigns.search_dropdown_open
      assert updated.assigns.flash["error"] == "Notion integration is not configured."
    end

    test "clear_search resets assignments" do
      socket =
        kb_socket(%{
          query: "Docs",
          results: [%{id: "1"}],
          search_performed: true,
          search_dropdown_open: true,
          search_feedback: "Great"
        })

      {:noreply, updated} = KbIndexLive.handle_event("clear_search", %{}, socket)

      assert updated.assigns.query == ""
      assert updated.assigns.results == []
      refute updated.assigns.search_performed
      refute updated.assigns.search_dropdown_open
      assert updated.assigns.search_feedback == nil
    end

    test "clear_search_key delegates to clear_search for supported keys" do
      socket = kb_socket(%{query: "Docs"})

      {:noreply, updated} =
        KbIndexLive.handle_event("clear_search_key", %{"key" => "Escape"}, socket)

      assert updated.assigns.query == ""
    end

    test "clear_search_key ignores unsupported keys" do
      socket = kb_socket(%{query: "Docs"})

      assert {:noreply, ^socket} =
               KbIndexLive.handle_event("clear_search_key", %{"key" => "Shift"}, socket)
    end

    test "toggle_mobile_menu flips assign" do
      socket = kb_socket(%{mobile_menu_open: false})

      {:noreply, updated} = KbIndexLive.handle_event("toggle_mobile_menu", %{}, socket)
      assert updated.assigns.mobile_menu_open
    end

    test "close_search_dropdown sets dropdown closed" do
      socket = kb_socket(%{search_dropdown_open: true})

      {:noreply, updated} =
        KbIndexLive.handle_event("close_search_dropdown", %{}, socket)

      refute updated.assigns.search_dropdown_open
    end

    test "toggle_collection ignores blank ids" do
      socket = kb_socket(%{expanded_collections: MapSet.new([1])})

      assert {:noreply, ^socket} =
               KbIndexLive.handle_event("toggle_collection", %{"id" => ""}, socket)
    end

    test "toggle_collection collapses expanded entries" do
      socket = kb_socket(%{expanded_collections: MapSet.new(["alpha"])})

      {:noreply, updated} =
        KbIndexLive.handle_event("toggle_collection", %{"id" => "alpha"}, socket)

      refute MapSet.member?(updated.assigns.expanded_collections, "alpha")
    end

    test "copy_share_link pushes clipboard event" do
      socket = kb_socket(%{})

      {:noreply, updated} =
        KbIndexLive.handle_event("copy_share_link", %{"url" => "https://kb/doc"}, socket)

      assert updated.assigns.flash["info"] == "Share link copied to clipboard"

      assert updated.private.live_temp[:push_events] == [
               ["copy-to-clipboard", %{text: "https://kb/doc"}]
             ]
    end
  end

  defp kb_socket(assigns) do
    %Phoenix.LiveView.Socket{
      endpoint: DashboardSSDWeb.Endpoint,
      view: KbIndexLive,
      root_pid: self(),
      transport_pid: self(),
      private: %{live_action: :index, live_temp: %{flash: %{}}},
      assigns:
        %{
          __changed__: %{},
          flash: %{},
          mobile_menu_open: false,
          query: "",
          results: [],
          search_performed: false,
          search_dropdown_open: false,
          search_feedback: nil,
          expanded_collections: MapSet.new(),
          documents_by_collection: %{},
          documents: [],
          selected_collection_id: nil,
          current_user: %{}
        }
        |> Map.merge(assigns)
    }
  end
end
