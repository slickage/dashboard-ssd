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
  end
end
