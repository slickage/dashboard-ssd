# sobelow_skip ["Traversal.FileModule"]
defmodule DashboardSSD.Coverage.CoverallsCiRunner do
  @moduledoc """
  Helper module that implements the logic behind `mix coveralls.ci`, including
  seeding GitHub environment variables, generating stub event payloads, and
  delegating to `coveralls.multiple` with the proper upload types.
  """

  # sobelow_skip ["Traversal.FileModule"]
  @doc """
  Runs `coveralls.multiple` with GitHub-style defaults for ref/shas.
  """
  @spec run([binary()]) :: :ok
  def run(args) do
    event_path = ensure_event_file()

    {cleanup_env, token_present?} = with_env_defaults(event_path)
    types = if token_present?, do: ["local", "github"], else: ["local"]
    coveralls_args = args ++ Enum.flat_map(types, &["--type", &1])

    try do
      run_coveralls(coveralls_args)
    rescue
      e ->
        cond do
          coveralls_report_error?(e) and token_present? ->
            reraise e, __STACKTRACE__

          coveralls_report_error?(e) ->
            :ok

          true ->
            reraise e, __STACKTRACE__
        end
    after
      cleanup_env.()
      :ok = :file.delete(String.to_charlist(event_path))
    end

    :ok
  end

  defp with_env_defaults(event_path) do
    defaults = %{
      "GITHUB_EVENT_NAME" => "push",
      "GITHUB_REF" => default_ref(),
      "GITHUB_SHA" => default_sha(),
      "GITHUB_EVENT_PATH" => event_path,
      "GITHUB_TOKEN" => System.get_env("GITHUB_TOKEN") || "local-github-token"
    }

    newly_set =
      defaults
      |> Enum.filter(fn {key, _} -> blank?(System.get_env(key)) end)

    Enum.each(newly_set, fn {key, value} -> System.put_env(key, value) end)

    cleanup_env = fn ->
      Enum.each(newly_set, fn {key, _} -> System.delete_env(key) end)
    end

    {cleanup_env, !blank?(System.get_env("COVERALLS_REPO_TOKEN"))}
  end

  defp ensure_event_file do
    path =
      Path.join(System.tmp_dir!(), "github_event_stub_#{System.unique_integer([:positive])}.json")

    :ok = :file.write_file(path, ~s({"sender":{"login":"local-runner"}}))
    path
  end

  defp default_sha do
    git_cmd(["rev-parse", "HEAD"], String.duplicate("0", 40))
  end

  defp default_ref do
    branch = git_cmd(["rev-parse", "--abbrev-ref", "HEAD"], "local")
    "refs/heads/#{branch}"
  end

  defp git_cmd(args, fallback) do
    case System.cmd("git", args) do
      {output, 0} -> String.trim(output)
      _ -> fallback
    end
  end

  defp blank?(value), do: value in [nil, ""]

  defp run_coveralls(args) do
    case Application.get_env(:dashboard_ssd, :coveralls_ci_runner) do
      nil -> mix_task_run("coveralls.multiple", args)
      runner -> runner.run("coveralls.multiple", args)
    end
  end

  defp mix_task_run(task, args) do
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

  @spec coveralls_report_error?(Exception.t()) :: boolean()
  defp coveralls_report_error?(%{__struct__: module}) when is_atom(module) do
    module == excoveralls_report_upload_error_module()
  end

  defp excoveralls_report_upload_error_module do
    module = Module.concat(ExCoveralls, ReportUploadError)

    if Code.ensure_loaded?(module) do
      module
    else
      nil
    end
  end
end
