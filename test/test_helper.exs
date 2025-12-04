ExUnit.start(capture_log: true)
Application.ensure_all_started(:mox)
Mox.set_mox_global()
Ecto.Adapters.SQL.Sandbox.mode(DashboardSSD.Repo, :manual)
