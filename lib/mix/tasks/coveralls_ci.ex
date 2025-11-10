defmodule Mix.Tasks.Coveralls.Ci do
  @moduledoc """
  Runs `coveralls.multiple` with sane defaults that mimic GitHub Actions and
  provides GitHub-style environment defaults. Existing environment variables
  always win; we only set defaults when the variables are missing.
  """
  use Mix.Task

  @shortdoc "Run coveralls.multiple with GitHub-like defaults"
  @preferred_cli_env :test

  @doc """
  Executes `coveralls.multiple`, populating any missing GitHub environment
  variables so the run mirrors CI. When no `COVERALLS_REPO_TOKEN` is present the
  Coveralls upload step is skipped but local coverage still runs.
  """
  @spec run([binary()]) :: :ok
  def run(args) do
    event_path = ensure_event_file()

    {cleanup_env, token_present?} = with_env_defaults(event_path)
    types = if token_present?, do: ["local", "github"], else: ["local"]
    coveralls_args = args ++ Enum.flat_map(types, &["--type", &1])

    try do
      Mix.Task.run("coveralls.multiple", coveralls_args)
    rescue
      e ->
        cond do
          coveralls_report_error?(e) and token_present? ->
            reraise e, __STACKTRACE__

          coveralls_report_error?(e) ->
            Mix.shell().info(
              "Skipping Coveralls upload (#{Exception.message(e)}). Set COVERALLS_REPO_TOKEN to test full pipeline locally."
            )

          true ->
            reraise e, __STACKTRACE__
        end
    after
      cleanup_env.()
      File.rm(event_path)
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

    File.write!(path, ~s({"sender":{"login":"local-runner"}}))
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
