defmodule DashboardSSD.Coverage.CoverallsCiRunnerTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias DashboardSSD.Coverage.CoverallsCiRunner

  defmodule RunnerStub do
    def run(task, args) do
      send(
        self(),
        {:runner_called, task, args, System.get_env("GITHUB_SHA"), System.get_env("GITHUB_REF")}
      )
    end
  end

  defmodule ErrorRunner do
    def run(_, _) do
      raise ExCoveralls.ReportUploadError, "upload failed"
    end
  end

  describe "run/1" do
    test "sets missing GitHub env vars and invokes the coveralls runner" do
      env_keys = [
        "GITHUB_EVENT_NAME",
        "GITHUB_REF",
        "GITHUB_SHA",
        "GITHUB_EVENT_PATH",
        "GITHUB_TOKEN"
      ]

      original_env = for key <- env_keys, into: %{}, do: {key, System.get_env(key)}

      Enum.each(env_keys, &System.delete_env/1)
      System.delete_env("COVERALLS_REPO_TOKEN")

      Application.put_env(:dashboard_ssd, :coveralls_ci_runner, RunnerStub)

      on_exit(fn ->
        Application.delete_env(:dashboard_ssd, :coveralls_ci_runner)

        Enum.each(env_keys, fn key ->
          case original_env[key] do
            nil -> System.delete_env(key)
            value -> System.put_env(key, value)
          end
        end)
      end)

      assert :ok = CoverallsCiRunner.run(["--foo"])

      assert_receive {:runner_called, "coveralls.multiple", ["--foo", "--type", "local"], _sha,
                      _ref}
    end

    test "logs a friendly message when report upload fails without a token" do
      Application.put_env(:dashboard_ssd, :coveralls_ci_runner, ErrorRunner)
      System.delete_env("COVERALLS_REPO_TOKEN")

      on_exit(fn ->
        Application.delete_env(:dashboard_ssd, :coveralls_ci_runner)
      end)

      output =
        capture_io(fn ->
          assert :ok = CoverallsCiRunner.run([])
        end)

      assert output =~ "Skipping Coveralls upload"
    end

    test "re-raises upload errors when a repo token is present" do
      System.put_env("COVERALLS_REPO_TOKEN", "token")
      Application.put_env(:dashboard_ssd, :coveralls_ci_runner, ErrorRunner)

      on_exit(fn ->
        System.delete_env("COVERALLS_REPO_TOKEN")
        Application.delete_env(:dashboard_ssd, :coveralls_ci_runner)
      end)

      assert_raise ExCoveralls.ReportUploadError, fn ->
        CoverallsCiRunner.run([])
      end
    end
  end
end
