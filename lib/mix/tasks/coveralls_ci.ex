defmodule Mix.Tasks.Coveralls.Ci do
  @moduledoc """
  Thin Mix task wrapper that delegates to
  `DashboardSSD.Coverage.CoverallsCiRunner`.
  """
  use Mix.Task

  alias DashboardSSD.Coverage.CoverallsCiRunner

  @shortdoc "Run coveralls.multiple with GitHub-like defaults"
  @preferred_cli_env :test

  @impl Mix.Task
  def run(args) do
    CoverallsCiRunner.run(args)
  end
end
