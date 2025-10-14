defmodule DashboardSSD.KnowledgeBase.InstrumentationTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias DashboardSSD.KnowledgeBase.Instrumentation
  alias Tesla.Env

  describe "with_request_span/3" do
    test "emits telemetry metadata for success and failure paths" do
      handler_id = {:instrumentation_test, make_ref()}

      :ok =
        :telemetry.attach(
          handler_id,
          Instrumentation.event(),
          fn event, measurements, metadata, _ ->
            send(self(), {:telemetry_event, event, measurements, metadata})
          end,
          %{}
        )

      {:ok, %Env{status: 200}} =
        Instrumentation.with_request_span(:search, %{method: :get, path: "/ok"}, fn ->
          {:ok, %Env{status: 200}}
        end)

      assert_receive {:telemetry_event, _event, measurements, metadata}
      assert is_integer(measurements.duration)
      assert metadata.status == :ok
      assert metadata.http_status == 200
      assert metadata.operation == :search

      {:error, {:http_error, 429, %{error: "rate"}}} =
        Instrumentation.with_request_span(:search, %{method: :get, path: "/retry"}, fn ->
          {:error, {:http_error, 429, %{error: "rate"}}}
        end)

      assert_receive {:telemetry_event, _event, _measurements, metadata}
      assert metadata.status == :error
      assert metadata.http_status == 429
      assert metadata.error == %{error: "rate"}

      {:error, :timeout} =
        Instrumentation.with_request_span(:search, %{attempt: 2}, fn ->
          {:error, :timeout}
        end)

      assert_receive {:telemetry_event, _event, _measurements, metadata}
      assert metadata.status == :error
      assert metadata.error == :timeout

      :other =
        Instrumentation.with_request_span(:search, %{}, fn ->
          :other
        end)

      assert_receive {:telemetry_event, _event, _measurements, metadata}
      assert metadata.status == :ok

      :telemetry.detach(handler_id)
    end
  end

  describe "logger attachment" do
    test "logs structured output for success and failure" do
      handler_id = {:instrumentation_logger_status, make_ref()}

      :ok =
        :telemetry.attach(
          handler_id,
          Instrumentation.event(),
          fn _event, _measurements, metadata, _ ->
            send(self(), {:logger_metadata, metadata.status, metadata})
          end,
          %{}
        )

      log =
        capture_log([level: :info], fn ->
          assert :ok == Instrumentation.attach_logger(:instrumentation_logger_test)

          try do
            {:ok, _} =
              Instrumentation.with_request_span(:search, %{method: :get, path: "/ok"}, fn ->
                {:ok, %Env{status: 200}}
              end)

            {:error, {:http_error, 500, %{reason: "boom"}}} =
              Instrumentation.with_request_span(:search, %{method: :get, path: "/fail"}, fn ->
                {:error, {:http_error, 500, %{reason: "boom"}}}
              end)
          after
            Instrumentation.detach_logger(:instrumentation_logger_test)
          end
        end)

      assert_receive {:logger_metadata, :ok, metadata}
      assert metadata.operation == :search
      assert_receive {:logger_metadata, :error, metadata}
      assert metadata.http_status == 500

      :telemetry.detach(handler_id)

      assert log =~ "Notion request failed"
      assert log =~ "Notion request failed"
    end

    test "returns already exists when attaching twice" do
      assert :ok == Instrumentation.attach_logger(:duplicate_logger_test)
      assert {:error, :already_exists} == Instrumentation.attach_logger(:duplicate_logger_test)
      Instrumentation.detach_logger(:duplicate_logger_test)
    end

    test "detach_logger tolerates missing handler" do
      assert {:error, :not_found} == Instrumentation.detach_logger(:unknown_handler)
    end

    test "handles unexpected statuses without crashing" do
      assert :ok ==
               Instrumentation.handle_event(
                 Instrumentation.event(),
                 %{duration: 1_000},
                 %{status: :unknown, method: :get, path: "/kb"},
                 %{}
               )
    end
  end
end
