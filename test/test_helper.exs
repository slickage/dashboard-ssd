ExUnit.start()
Application.ensure_all_started(:mox)
Ecto.Adapters.SQL.Sandbox.mode(DashboardSSD.Repo, :manual)
