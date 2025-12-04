defmodule Mix.Tasks.SharedDocuments.Sync do
  @dialyzer {:nowarn_function, run: 1}
  @dialyzer {:nowarn_function, behaviour_info: 1}
  @behaviour Mix.Task

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

  @doc """
  Bootstraps the shared document synchronization pipeline with optional
  source/dry-run/force flags.
  """
  @spec run([String.t()]) :: :ok | no_return()
  @impl true
  def run(args) do
    {opts, _argv, invalid} = OptionParser.parse(args, switches: @switches, aliases: @aliases)

    if invalid != [] do
      invalid_opts = Enum.map_join(invalid, ", ", fn {opt, _} -> to_string(opt) end)
      mix_raise("Invalid option(s): #{invalid_opts}")
    end

    mix_task_run("app.start")

    runner =
      Application.get_env(
        :dashboard_ssd,
        :shared_documents_sync_runner,
        DashboardSSD.Documents.SharedDocumentsSync
      )

    exec_opts = build_exec_opts(opts)

    if runner_available?(runner) do
      runner.sync_all(exec_opts)

      mix_shell_info(
        "Shared documents sync finished (sources=#{Enum.join(exec_opts.sources, ",")})."
      )
    else
      mix_shell_info(
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
      _ -> mix_raise("Unsupported --source value #{inspect(source)}. Use drive or notion.")
    end
  end

  defp normalize_source(source), do: mix_raise("Unsupported --source value #{inspect(source)}.")

  defp runner_available?(module),
    do: Code.ensure_loaded?(module) and function_exported?(module, :sync_all, 1)

  defp mix_task_run(task, args \\ []) do
    cond do
      function_exported?(Mix.Task, :run, 2) ->
        # credo:disable-for-next-line Credo.Check.Refactor.Apply
        apply(Mix.Task, :run, [task, args])

      function_exported?(Mix.Task, :run, 1) ->
        # credo:disable-for-next-line Credo.Check.Refactor.Apply
        apply(Mix.Task, :run, [task])

      true ->
        :ok
    end
  end

  defp mix_raise(message) do
    if function_exported?(Mix, :raise, 1) do
      # credo:disable-for-next-line Credo.Check.Refactor.Apply
      apply(Mix, :raise, [message])
    else
      raise(message)
    end
  end

  defp mix_shell_info(message) do
    if function_exported?(Mix, :shell, 0) do
      # credo:disable-for-next-line Credo.Check.Refactor.Apply
      shell = apply(Mix, :shell, [])

      if function_exported?(shell, :info, 1) do
        # credo:disable-for-next-line Credo.Check.Refactor.Apply
        apply(shell, :info, [message])
      end
    end
  end

  @doc false
  @spec behaviour_info(atom()) :: keyword() | :undefined
  def behaviour_info(:callbacks), do: [run: 1]

  @doc false
  def behaviour_info(_), do: :undefined
end
