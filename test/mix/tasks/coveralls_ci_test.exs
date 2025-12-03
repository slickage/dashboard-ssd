defmodule Mix.Tasks.Coveralls.CiTest do
  use ExUnit.Case, async: false

  alias Mix.Tasks.Coveralls.Ci

  defmodule RunnerStub do
    def run(task, args) do
      send(self(), {:coveralls_run, task, args})
      :ok
    end
  end

  defmodule RunnerRaises do
    def run(_task, _args) do
      raise Module.concat(ExCoveralls, ReportUploadError), "upload failed"
    end
  end

  setup do
    original_runner = Application.get_env(:dashboard_ssd, :coveralls_ci_runner)

    env_keys = [
      "COVERALLS_REPO_TOKEN",
      "GITHUB_EVENT_NAME",
      "GITHUB_REF",
      "GITHUB_SHA",
      "GITHUB_EVENT_PATH",
      "GITHUB_TOKEN"
    ]

    previous_env =
      Map.new(env_keys, fn key -> {key, System.get_env(key)} end)

    on_exit(fn ->
      Application.put_env(:dashboard_ssd, :coveralls_ci_runner, original_runner)

      Enum.each(previous_env, fn
        {key, nil} -> System.delete_env(key)
        {key, value} -> System.put_env(key, value)
      end)
    end)

    System.delete_env("COVERALLS_REPO_TOKEN")
    Application.put_env(:dashboard_ssd, :coveralls_ci_runner, RunnerStub)

    :ok
  end

  test "defaults to local type when repo token missing" do
    assert :ok = Ci.run([])
    assert_received {:coveralls_run, "coveralls.multiple", ["--type", "local"]}
  end

  test "includes github upload when repo token present" do
    System.put_env("COVERALLS_REPO_TOKEN", "token")

    assert :ok = Ci.run([])

    assert_received {:coveralls_run, "coveralls.multiple",
                     ["--type", "local", "--type", "github"]}
  end

  test "swallows upload errors when token missing" do
    Application.put_env(:dashboard_ssd, :coveralls_ci_runner, RunnerRaises)

    assert :ok = Ci.run([])
  end

  test "propagates upload errors when token present" do
    Application.put_env(:dashboard_ssd, :coveralls_ci_runner, RunnerRaises)
    System.put_env("COVERALLS_REPO_TOKEN", "token")

    assert_raise Module.concat(ExCoveralls, ReportUploadError), fn ->
      Ci.run([])
    end
  end
end
