defmodule DashboardSSD.WorkspaceBootstrapStub do
  @moduledoc false

  def bootstrap(project, opts) do
    maybe_send(project, opts)
    {:ok, %{sections: []}}
  end

  defp maybe_send(project, opts) do
    case :persistent_term.get({:workspace_test_pid}, nil) do
      nil -> :ok
      pid -> send(pid, {:workspace_bootstrap, project.id, opts[:sections]})
    end
  end
end
