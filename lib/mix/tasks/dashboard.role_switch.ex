defmodule Mix.Tasks.Dashboard.RoleSwitch do
  @moduledoc """
  Mix task to change a user's role for local testing.

    - Boots the application and switches a user’s role via `Accounts.switch_user_role/2`.
  - Provides CLI options (`--role`, `--email`) with helpful errors/prompts.
  - Guards against execution in production environments.
  """
  use Mix.Task
  require Mix

  alias DashboardSSD.Accounts
  alias DashboardSSD.Accounts.User
  alias DashboardSSD.Repo
  alias Mix.Error, as: MixError
  alias Mix.Task, as: MixTask

  @shortdoc "Switches a user's role (dev/test only)"

  @impl Mix.Task
  def run(argv) do
    MixTask.run("app.start")

    {opts, _, _} = OptionParser.parse(argv, strict: [role: :string, email: :string])

    ensure_non_prod!()

    role = Keyword.get(opts, :role)

    role || raise!("--role is required (admin, employee, client)")

    target = Keyword.get(opts, :email) || default_user_email()

    case Accounts.switch_user_role(target, role) do
      {:ok, %User{} = updated} ->
        IO.puts("Updated #{updated.email} to role #{role}")

      {:error, :user_not_found} ->
        raise!("Could not find user #{target}. Provide --email or create a user first.")

      {:error, changeset} ->
        raise!("Failed to update role: #{inspect(changeset)}")
    end
  end

  defp ensure_non_prod! do
    env = Application.get_env(:dashboard_ssd, :env, :dev)

    if env == :prod do
      raise!("dashboard.role_switch is only available in dev or test environments")
    end
  end

  defp default_user_email do
    case Repo.one(User) do
      %User{email: email} -> email
      nil -> raise!("No users exist. Use --email after creating a user.")
    end
  end

  defp raise!(message), do: raise(MixError, message: message)
end
