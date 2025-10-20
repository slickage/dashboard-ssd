defmodule DashboardSSD.Analytics.WorkloadTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Analytics.Workload

  describe "summarize_all_projects/1" do
    test "returns zero summary when Linear is not enabled" do
      # Mock LinearUtils.linear_enabled? to return false
      Application.put_env(:dashboard_ssd, :integrations, linear_token: nil)

      result = Workload.summarize_all_projects([])
      assert result == %{total: 0, in_progress: 0, finished: 0}
    end
  end

  describe "percent/2" do
    test "returns 0 when total is 0" do
      assert Workload.percent(5, 0) == 0
    end

    test "calculates percentage correctly" do
      assert Workload.percent(25, 100) == 25
      assert Workload.percent(1, 3) == 33
      assert Workload.percent(2, 3) == 66
    end
  end
end
