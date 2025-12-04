defmodule Mix.Tasks.Dashboard.RoleSwitch do
  @dialyzer {:nowarn_function, run: 1}

  @moduledoc """
  Mix task to change a user's role for local testing.

    - Boots the application and switches a user’s role via `Accounts.switch_user_role/2`.
  - Provides CLI options (`--role`, `--email`) with helpful errors/prompts.
  - Guards against execution in production environments.
  """
  use Mix.Task
  @shortdoc "Switches a user's role (dev/test only)"
  alias DashboardSSD.Accounts
  alias DashboardSSD.Accounts.User
  alias DashboardSSD.Repo

  @impl Mix.Task
  @doc """
  Switches the sandboxed user's role so developers can preview RBAC scenarios.

  Supports `--role` (required) and `--email`; if the email is omitted the task
  uses the first user found in the database.
  """
  @spec run([String.t()]) :: :ok | no_return()
  def run(argv) do
    mix_task_run("app.start")

    {opts, _, _} = OptionParser.parse(argv, strict: [role: :string, email: :string])

    ensure_non_prod!()

    role = Keyword.get(opts, :role)

    role || mix_raise("--role is required (admin, employee, client)")

    target = Keyword.get(opts, :email) || default_user_email()

    case Accounts.switch_user_role(target, role) do
      {:ok, %User{} = updated} ->
        IO.puts("Updated #{updated.email} to role #{role}")

      {:error, :user_not_found} ->
        mix_raise("Could not find user #{target}. Provide --email or create a user first.")

      {:error, changeset} ->
        mix_raise("Failed to update role: #{inspect(changeset)}")
    end
  end

  defp ensure_non_prod! do
    env = Application.get_env(:dashboard_ssd, :env, :dev)

    if env == :prod do
      mix_raise("dashboard.role_switch is only available in dev or test environments")
    end
  end

  defp default_user_email do
    case Repo.one(User) do
      %User{email: email} -> email
      nil -> mix_raise("No users exist. Use --email after creating a user.")
    end
  end

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

  @doc false
  @spec behaviour_info(atom()) :: keyword() | :undefined
  def behaviour_info(:callbacks), do: [run: 1]

  @doc false
  def behaviour_info(_), do: :undefined
end
