defmodule Mix.Tasks.SharedDocuments.Sync do
  @moduledoc """
  Boots the DashboardSSD application and triggers the Shared Documents sync
  pipeline so Drive/Notion metadata stays in lockstep with the database.

  The task is intentionally lightweight so engineers and CI can invoke it in
  local/dev sandboxes:

      mix shared_documents.sync
      mix shared_documents.sync --source drive --force
      mix shared_documents.sync --source drive --source notion --dry-run

  Options are passed to the configured sync runner (once implemented) so that
  downstream logic can choose which sources to operate on or whether to run in
  dry-run mode.
  """
  use Mix.Task

  @shortdoc "Triggers the shared documents sync pipeline"

  @switches [
    source: :keep,
    dry_run: :boolean,
    force: :boolean
  ]

  @aliases [
    s: :source,
    d: :dry_run,
    f: :force
  ]

  @impl true
  def run(args) do
    {opts, _argv, invalid} = OptionParser.parse(args, switches: @switches, aliases: @aliases)

    if invalid != [] do
      invalid_opts =
        invalid
        |> Enum.map(fn {opt, _} -> to_string(opt) end)
        |> Enum.join(", ")

      Mix.raise("Invalid option(s): #{invalid_opts}")
    end

    Mix.Task.run("app.start")

    runner =
      Application.get_env(
        :dashboard_ssd,
        :shared_documents_sync_runner,
        DashboardSSD.Documents.SharedDocumentsSync
      )

    exec_opts = build_exec_opts(opts)

    if runner_available?(runner) do
      runner.sync_all(exec_opts)

      Mix.shell().info(
        "Shared documents sync finished (sources=#{Enum.join(exec_opts.sources, ",")})."
      )
    else
      Mix.shell().info(
        "Shared documents sync runner #{inspect(runner)} is not available; skipping."
      )
    end
  end

  defp build_exec_opts(opts) do
    sources =
      opts
      |> Keyword.get_values(:source)
      |> Enum.map(&normalize_source/1)
      |> case do
        [] -> [:drive, :notion]
        list -> list
      end

    %{
      sources: sources,
      dry_run?: Keyword.get(opts, :dry_run, false),
      force?: Keyword.get(opts, :force, false)
    }
  end

  defp normalize_source(source) when is_binary(source) do
    case String.downcase(source) do
      "drive" -> :drive
      "notion" -> :notion
      _ -> Mix.raise("Unsupported --source value #{inspect(source)}. Use drive or notion.")
    end
  end

  defp normalize_source(source), do: Mix.raise("Unsupported --source value #{inspect(source)}.")

  defp runner_available?(module),
    do: Code.ensure_loaded?(module) and function_exported?(module, :sync_all, 1)
end
