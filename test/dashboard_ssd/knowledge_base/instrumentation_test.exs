defmodule DashboardSSD.KnowledgeBase.InstrumentationTest do
  use ExUnit.Case, async: true

  alias DashboardSSD.KnowledgeBase.Instrumentation

  describe "with_request_span/3" do
    test "emits telemetry events with success metadata" do
      handler_id = {:kb_telemetry, make_ref()}
      parent = self()

      :ok =
        :telemetry.attach(
          handler_id,
          Instrumentation.event(),
          fn event, measurements, metadata, _ ->
            send(parent, {:telemetry_event, event, measurements, metadata})
          end,
          %{}
        )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      env = %Tesla.Env{status: 200, body: %{}}

      assert {:ok, ^env} =
               Instrumentation.with_request_span(
                 :search,
                 %{method: :post, path: "/v1/search", attempt: 1},
                 fn ->
                   {:ok, env}
                 end
               )

      assert_receive {:telemetry_event,
                      [:dashboard_ssd, :knowledge_base, :notion, :request, :stop], measurements,
                      metadata},
                     1000

      assert %{
               status: :ok,
               operation: :search,
               http_status: 200,
               method: :post,
               path: "/v1/search",
               attempt: 1
             } =
               metadata

      assert is_integer(measurements.duration)
    end

    test "logs structured payloads for failures" do
      handler_id = {:kb_logger, make_ref()}

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          Instrumentation.detach_logger(handler_id)
          :ok = Instrumentation.attach_logger(handler_id)
          on_exit(fn -> Instrumentation.detach_logger(handler_id) end)

          Instrumentation.with_request_span(
            :query_database,
            %{method: :post, path: "/v1/databases/db/query", attempt: 2},
            fn ->
              {:error, {:http_error, 429, %{"error" => "rate_limited"}}}
            end
          )
        end)

      assert log =~ "Notion request failed"
    end

    test "propagates simple {:error, reason} responses and annotates metadata" do
      handler_id = {:kb_error_telemetry, make_ref()}
      parent = self()

      :ok =
        :telemetry.attach(
          handler_id,
          Instrumentation.event(),
          fn event, measurements, metadata, _ ->
            send(parent, {:telemetry_event, event, measurements, metadata})
          end,
          %{}
        )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      assert {:error, :timeout} =
               Instrumentation.with_request_span(:query_database, %{method: :get}, fn ->
                 {:error, :timeout}
               end)

      assert_receive {:telemetry_event, _event, measurements, metadata}, 1000
      assert metadata.status == :error
      assert metadata.error == :timeout
      assert is_integer(measurements.duration)
    end

    test "marks non-telemetry return values as successful" do
      handler_id = {:kb_success_telemetry, make_ref()}
      parent = self()

      :ok =
        :telemetry.attach(
          handler_id,
          Instrumentation.event(),
          fn event, measurements, metadata, _ ->
            send(parent, {:telemetry_event, event, measurements, metadata})
          end,
          %{}
        )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      assert :ok =
               Instrumentation.with_request_span(:ping, %{method: :get, path: "/ping"}, fn ->
                 :ok
               end)

      assert_receive {:telemetry_event, _event, measurements, metadata}, 1000
      assert metadata.status == :ok
      refute Map.has_key?(metadata, :http_status)
      assert is_integer(measurements.duration)
    end
  end

  describe "detach_logger/1" do
    test "returns {:error, :not_found} when the handler is not attached" do
      assert {:error, :not_found} = Instrumentation.detach_logger({:missing_handler, make_ref()})
    end

    test "successfully detaches an attached handler" do
      handler_id = {:kb_detach_ok, make_ref()}

      try do
        assert :ok = Instrumentation.attach_logger(handler_id)
        assert :ok = Instrumentation.detach_logger(handler_id)
      after
        Instrumentation.detach_logger(handler_id)
      end
    end
  end

  describe "event/0" do
    test "returns the fully qualified stop event name" do
      assert [:dashboard_ssd, :knowledge_base, :notion, :request, :stop] ==
               Instrumentation.event()
    end
  end

  describe "handle_event/4" do
    test "handles unexpected statuses without raising" do
      assert :ok ==
               Instrumentation.handle_event(
                 Instrumentation.event(),
                 %{duration: System.convert_time_unit(1, :millisecond, :native)},
                 %{status: :retry, operation: :sync},
                 %{}
               )
    end
  end

  describe "attach_logger/1" do
    test "returns {:error, :already_exists} when handler id is reused" do
      handler_id = {:kb_logger_dup, make_ref()}

      try do
        assert :ok = Instrumentation.attach_logger(handler_id)
        assert {:error, :already_exists} = Instrumentation.attach_logger(handler_id)
      after
        Instrumentation.detach_logger(handler_id)
      end
    end
  end
end
