defmodule DashboardSSD.Projects.DrivePermissionWorker do
  @moduledoc """
  Handles Drive ACL share/unshare operations with retry/backoff semantics.
  """
  require Logger
  alias DashboardSSD.Integrations

  @max_attempts 3
  @base_backoff 3_000

  @spec share(String.t(), map()) :: :ok
  def share(folder_id, params) do
    dispatch(fn -> do_share(folder_id, params, 1) end)
  end

  @spec unshare(String.t(), String.t()) :: :ok
  def unshare(folder_id, permission_id) do
    dispatch(fn -> do_unshare(folder_id, permission_id, 1) end)
  end

  @spec revoke_email(String.t(), String.t() | nil) :: :ok
  def revoke_email(_folder_id, nil), do: :ok

  def revoke_email(folder_id, email) do
    dispatch(fn -> do_revoke_email(folder_id, String.downcase(email), 1) end)
  end

  defp do_share(folder_id, params, attempt) do
    case Integrations.drive_share_folder(folder_id, params) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        retry(:share, reason, attempt, fn -> do_share(folder_id, params, attempt + 1) end)
    end
  end

  defp do_unshare(folder_id, permission_id, attempt) do
    case Integrations.drive_unshare_folder(folder_id, permission_id) do
      :ok ->
        :ok

      {:error, reason} ->
        retry(:unshare, reason, attempt, fn ->
          do_unshare(folder_id, permission_id, attempt + 1)
        end)
    end
  end

  defp retry(_op, _reason, attempt, _fun) when attempt > @max_attempts do
    Logger.error("Drive permission worker exceeded retries", attempt: attempt)
    :error
  end

  defp retry(op, reason, attempt, fun) do
    Logger.warning("Drive permission #{op} failed", attempt: attempt, reason: inspect(reason))
    Process.sleep(@base_backoff * attempt)
    fun.()
  end

  defp do_revoke_email(folder_id, email, attempt) do
    case Integrations.drive_list_permissions(folder_id) do
      {:ok, permissions} ->
        case find_permission_id(permissions, email) do
          nil -> :ok
          permission_id -> do_unshare(folder_id, permission_id, 1)
        end

      {:error, reason} ->
        retry(:unshare_lookup, reason, attempt, fn ->
          do_revoke_email(folder_id, email, attempt + 1)
        end)
    end
  end

  defp find_permission_id(permissions, email) do
    Enum.find_value(permissions, fn permission ->
      perm_email = permission["emailAddress"] || permission[:emailAddress]

      if is_binary(perm_email) and String.downcase(perm_email) == email do
        permission["id"] || permission[:id]
      else
        nil
      end
    end)
  end

  defp dispatch(fun) when is_function(fun, 0) do
    cond do
      inline?() ->
        fun.()
        :ok

      disabled?() ->
        :ok

      true ->
        Task.Supervisor.start_child(DashboardSSD.TaskSupervisor, fn -> fun.() end)
        :ok
    end
  end

  defp inline? do
    Application.get_env(:dashboard_ssd, :drive_permission_worker_inline, false)
  end

  defp disabled? do
    Application.get_env(:dashboard_ssd, :drive_permission_worker_disabled, false) ||
      Application.get_env(:dashboard_ssd, :env, :dev) == :test
  end
end
