defmodule DashboardSSD.Projects.HealthChecksSchedulerTest do
  use DashboardSSD.DataCase, async: false

  alias DashboardSSD.{Clients, Deployments, Projects}
  alias DashboardSSD.Projects.HealthChecksScheduler

  describe "options and lifecycle" do
    test "stop returns ok when scheduler not running" do
      assert :ok = HealthChecksScheduler.stop(:nonexistent_scheduler)
    end

    test "honours custom interval and initial delay" do
      {:ok, pid} =
        start_scheduler(
          {HealthChecksScheduler, name: :hc_interval_test, initial_delay_ms: 5, interval_ms: 10}
        )

      state = :sys.get_state(pid)
      assert state.interval == 10
      :ok = stop_scheduler(pid)
    end

    test "ignores tick while run already in progress" do
      ref = make_ref()

      {:noreply, %{task_ref: ^ref} = state} =
        HealthChecksScheduler.handle_info(:tick, %{task_ref: ref})

      assert state.task_ref == ref
    end

    test "reschedules after task completes" do
      ref = make_ref()

      {:noreply, %{task_ref: nil}} =
        HealthChecksScheduler.handle_info({:DOWN, ref, :process, self(), :normal}, %{
          task_ref: ref,
          interval: 25,
          stop_from: nil
        })
    end

    test "ignores task results when ref matches" do
      ref = make_ref()
      state = %{task_ref: ref, interval: 10}
      assert {:noreply, ^state} = HealthChecksScheduler.handle_info({ref, :ok}, state)
    end

    test "ignores task results when ref differs" do
      state = %{task_ref: make_ref(), interval: 10}

      assert {:noreply, ^state} =
               HealthChecksScheduler.handle_info({make_ref(), :ok}, state)
    end

    test "records stop caller when task in progress" do
      from = {self(), make_ref()}
      state = %{task_ref: make_ref(), stop_from: nil}

      assert {:noreply, %{stop_from: ^from}} =
               HealthChecksScheduler.handle_call(:stop, from, state)
    end

    test "replies to stop caller when task completes" do
      ref = make_ref()
      from = {self(), make_ref()}
      ref_tag = elem(from, 1)

      state = %{task_ref: ref, interval: 25, stop_from: from}

      assert {:stop, :normal, %{task_ref: nil, stop_from: nil}} =
               HealthChecksScheduler.handle_info({:DOWN, ref, :process, self(), :normal}, state)

      assert_receive {^ref_tag, :ok}
    end
  end

  test "scheduler inserts a down status for unreachable HTTP endpoint" do
    {:ok, c} = Clients.create_client(%{name: "SchedC"})
    {:ok, p} = Projects.create_project(%{name: "SchedP", client_id: c.id})

    {:ok, _} =
      Deployments.upsert_health_check_setting(p.id, %{
        enabled: true,
        provider: "http",
        endpoint_url: "http://127.0.0.1:9/health"
      })

    # Start scheduler manually (even though app does not start it in test)
    {:ok, pid} = start_scheduler({HealthChecksScheduler, initial_delay_ms: 0, interval_ms: 50})

    assert :ok = wait_for_status(p.id)
    # Stop the scheduler to avoid further ticks
    :ok = stop_scheduler(pid)

    m = Deployments.latest_health_status_by_project_ids([p.id])
    assert Map.has_key?(m, p.id)
  end

  describe "http responses" do
    setup do
      {:ok, client} = Clients.create_client(%{name: "SchedHttp"})
      {:ok, project} = Projects.create_project(%{name: "SchedHttpProj", client_id: client.id})
      %{project: project}
    end

    test "treats 3xx as up", %{project: project} do
      bypass = Bypass.open()

      Bypass.stub(bypass, "GET", "/health", fn conn ->
        Plug.Conn.resp(conn, 302, "")
      end)

      {:ok, _} =
        Deployments.upsert_health_check_setting(project.id, %{
          enabled: true,
          provider: "http",
          endpoint_url: "http://127.0.0.1:#{bypass.port}/health"
        })

      {:ok, pid} =
        start_scheduler(
          {HealthChecksScheduler, name: :hc_http_up, initial_delay_ms: 0, interval_ms: 50}
        )

      assert {:ok, "up"} = wait_for_status(project.id, 50, "up")
      :ok = stop_scheduler(pid)
    end

    test "treats 4xx as degraded", %{project: project} do
      bypass = Bypass.open()

      Bypass.stub(bypass, "GET", "/health", fn conn ->
        Plug.Conn.resp(conn, 418, "teapot")
      end)

      {:ok, _} =
        Deployments.upsert_health_check_setting(project.id, %{
          enabled: true,
          provider: "http",
          endpoint_url: "http://127.0.0.1:#{bypass.port}/health"
        })

      {:ok, pid} =
        start_scheduler(
          {HealthChecksScheduler, name: :hc_http_degraded, initial_delay_ms: 0, interval_ms: 50}
        )

      assert {:ok, "degraded"} = wait_for_status(project.id, 50, "degraded")
      :ok = stop_scheduler(pid)
    end

    test "treats 5xx as down", %{project: project} do
      bypass = Bypass.open()

      Bypass.stub(bypass, "GET", "/health", fn conn ->
        Plug.Conn.resp(conn, 503, "busy")
      end)

      {:ok, _} =
        Deployments.upsert_health_check_setting(project.id, %{
          enabled: true,
          provider: "http",
          endpoint_url: "http://127.0.0.1:#{bypass.port}/health"
        })

      {:ok, pid} =
        start_scheduler(
          {HealthChecksScheduler, name: :hc_http_down, initial_delay_ms: 0, interval_ms: 50}
        )

      assert {:ok, "down"} = wait_for_status(project.id, 50, "down")
      :ok = stop_scheduler(pid)
    end

    test "treats unexpected statuses as degraded", %{project: project} do
      bypass = Bypass.open()

      Bypass.stub(bypass, "GET", "/health", fn conn ->
        Plug.Conn.resp(conn, 102, "processing")
      end)

      {:ok, _} =
        Deployments.upsert_health_check_setting(project.id, %{
          enabled: true,
          provider: "http",
          endpoint_url: "http://127.0.0.1:#{bypass.port}/health"
        })

      {:ok, pid} =
        start_scheduler(
          {HealthChecksScheduler, name: :hc_http_weird, initial_delay_ms: 0, interval_ms: 50}
        )

      assert {:ok, "degraded"} = wait_for_status(project.id, 50, "degraded")
      :ok = stop_scheduler(pid)
    end

    test "skips invalid provider configs", %{project: project} do
      {:ok, _} =
        Deployments.upsert_health_check_setting(project.id, %{
          enabled: true,
          provider: "custom",
          endpoint_url: nil
        })

      {:ok, pid} =
        start_scheduler(
          {HealthChecksScheduler, name: :hc_http_invalid, initial_delay_ms: 0, interval_ms: 20}
        )

      Process.sleep(100)
      :ok = stop_scheduler(pid)

      m = Deployments.latest_health_status_by_project_ids([project.id])
      refute Map.has_key?(m, project.id)
    end

    test "does not insert duplicate status when unchanged", %{project: project} do
      {:ok, _} = Deployments.create_health_check(%{project_id: project.id, status: "up"})

      bypass = Bypass.open()

      Bypass.stub(bypass, "GET", "/health", fn conn ->
        Plug.Conn.resp(conn, 200, "ok")
      end)

      {:ok, _} =
        Deployments.upsert_health_check_setting(project.id, %{
          enabled: true,
          provider: "http",
          endpoint_url: "http://127.0.0.1:#{bypass.port}/health"
        })

      count_before = Deployments.list_health_checks_by_project(project.id) |> length()

      {:ok, pid} =
        start_scheduler(
          {HealthChecksScheduler, name: :hc_http_repeat, initial_delay_ms: 0, interval_ms: 50}
        )

      assert {:ok, "up"} = wait_for_status(project.id, 50, "up")
      :ok = stop_scheduler(pid)

      count_after = Deployments.list_health_checks_by_project(project.id) |> length()
      assert count_after == count_before
    end
  end

  defp wait_for_status(project_id, attempts \\ 50, expected_status \\ nil)

  defp wait_for_status(project_id, 0, expected_status) do
    m = Deployments.latest_health_status_by_project_ids([project_id])

    case Map.get(m, project_id) do
      nil ->
        {:error, :timeout}

      status when expected_status in [nil, status] ->
        if expected_status, do: {:ok, status}, else: :ok

      status ->
        {:error, {:unexpected_status, status}}
    end
  end

  defp wait_for_status(project_id, attempts, expected_status) do
    m = Deployments.latest_health_status_by_project_ids([project_id])

    case Map.get(m, project_id) do
      nil ->
        Process.sleep(50)
        wait_for_status(project_id, attempts - 1, expected_status)

      status when expected_status in [nil, status] ->
        if expected_status, do: {:ok, status}, else: :ok

      _status ->
        Process.sleep(50)
        wait_for_status(project_id, attempts - 1, expected_status)
    end
  end

  defp start_scheduler(child_spec) do
    spec = Supervisor.child_spec(child_spec, restart: :temporary)
    start_supervised(spec)
  end

  defp stop_scheduler(pid), do: HealthChecksScheduler.stop(pid)
end
