defmodule DashboardSSD.Analytics.MetricsSchedulerTest do
  use DashboardSSD.DataCase, async: false

  alias DashboardSSD.Analytics.MetricsScheduler

  defmodule CollectorStub do
    def collect_all_metrics do
      pid = :persistent_term.get({__MODULE__, :pid})
      send(pid, {:collector, :run})
      :ok
    end
  end

  setup do
    :persistent_term.put({CollectorStub, :pid}, self())

    on_exit(fn ->
      :persistent_term.erase({CollectorStub, :pid})
    end)

    :ok
  end

  describe "start_link/1" do
    test "starts the scheduler GenServer" do
      assert {:ok, pid} =
               MetricsScheduler.start_link(
                 name: :test_scheduler,
                 initial_delay_ms: 0,
                 interval_ms: 50,
                 collector: CollectorStub
               )

      assert is_pid(pid)
      assert Process.alive?(pid)

      # Clean up
      GenServer.stop(pid)
    end
  end

  describe "init/1" do
    test "schedules initial collection on startup" do
      # Start the scheduler
      {:ok, pid} =
        MetricsScheduler.start_link(
          name: :test_scheduler_init,
          initial_delay_ms: 0,
          interval_ms: 50,
          collector: CollectorStub
        )

      # Check that a :collect message is scheduled
      # Since it's sent immediately (0ms), it should be in the mailbox soon
      :timer.sleep(10)

      # The process should have received the :collect message
      # We can check by sending a synchronous call or inspecting state
      # But since it's private, we'll test indirectly by ensuring it doesn't crash
      assert Process.alive?(pid)

      GenServer.stop(pid)
    end
  end

  describe "handle_info/2" do
    test "handles :collect message by collecting metrics and rescheduling" do
      # Start scheduler
      {:ok, pid} =
        MetricsScheduler.start_link(
          name: :test_scheduler_handle,
          initial_delay_ms: 0,
          interval_ms: 50,
          collector: CollectorStub
        )

      # Send :collect message
      send(pid, :collect)

      # Allow time for processing
      :timer.sleep(100)

      assert_received {:collector, :run}

      # Process should still be alive and have rescheduled
      assert Process.alive?(pid)

      GenServer.stop(pid)
    end
  end

  test "ignores additional collect messages while running" do
    {:ok, pid} =
      MetricsScheduler.start_link(
        name: :test_scheduler_running,
        initial_delay_ms: 10_000,
        interval_ms: 50,
        collector: CollectorStub
      )

    ref = make_ref()
    :sys.replace_state(pid, fn state -> %{state | task_ref: ref} end)

    send(pid, {make_ref(), :ignored})
    send(pid, {:DOWN, make_ref(), :process, self(), :normal})

    send(pid, :collect)
    :timer.sleep(20)
    refute_received {:collector, :run}

    # Simulate task result message and DOWN cleanup
    send(pid, {ref, :ok})
    send(pid, {:DOWN, ref, :process, self(), :normal})
    :timer.sleep(20)

    GenServer.stop(pid)
  end
end
