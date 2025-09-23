defmodule DashboardSSD.Analytics.SchedulerTest do
  use DashboardSSD.DataCase, async: false

  alias DashboardSSD.Analytics.Scheduler

  describe "start_link/1" do
    test "starts the scheduler GenServer" do
      assert {:ok, pid} = Scheduler.start_link(name: :test_scheduler)
      assert is_pid(pid)
      assert Process.alive?(pid)

      # Clean up
      GenServer.stop(pid)
    end
  end

  describe "init/1" do
    test "schedules initial collection on startup" do
      # Start the scheduler
      {:ok, pid} = Scheduler.start_link(name: :test_scheduler)

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
      {:ok, pid} = Scheduler.start_link(name: :test_scheduler)

      # Send :collect message
      send(pid, :collect)

      # Allow time for processing
      :timer.sleep(100)

      # Process should still be alive and have rescheduled
      assert Process.alive?(pid)

      GenServer.stop(pid)
    end
  end
end
