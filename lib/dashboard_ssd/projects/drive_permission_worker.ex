defmodule DashboardSSD.Projects.DrivePermissionWorker do
  @moduledoc """
  Handles Drive ACL share/unshare operations with retry/backoff semantics.
  """
  require Logger
  alias DashboardSSD.Integrations

  @max_attempts 3
  @base_backoff 3_000

  @doc """
  Shares the given Drive folder with the provided params asynchronously.
  """
  @spec share(String.t(), map()) :: :ok
  def share(folder_id, params) do
    dispatch(fn -> do_share(folder_id, params, 1) end)
  end

  @doc """
  Removes the Drive permission with the provided ID from the folder.
  """
  @spec unshare(String.t(), String.t()) :: :ok
  def unshare(folder_id, permission_id) do
    dispatch(fn -> do_unshare(folder_id, permission_id, 1) end)
  end

  @doc """
  Revokes any Drive permissions granted to the provided email address.
  """
  @spec revoke_email(String.t(), String.t() | nil) :: :ok
  def revoke_email(_folder_id, nil), do: :ok

  def revoke_email(folder_id, email) do
    dispatch(fn -> do_revoke_email(folder_id, String.downcase(email), 1) end)
  end

  defp do_share(folder_id, params, attempt) do
    start_time = System.monotonic_time()

    case Integrations.drive_share_folder(folder_id, params) do
      {:ok, _} ->
        emit_drive_acl_event(start_time, :share, :ok, attempt, %{
          role: access_param(params, [:role, "role"]),
          folder_id: folder_id
        })

        :ok

      {:error, reason} ->
        emit_drive_acl_event(start_time, :share, :error, attempt, %{
          role: access_param(params, [:role, "role"]),
          folder_id: folder_id,
          error: inspect(reason)
        })

        retry(:share, reason, attempt, fn -> do_share(folder_id, params, attempt + 1) end)
    end
  end

  defp do_unshare(folder_id, permission_id, attempt) do
    start_time = System.monotonic_time()

    case Integrations.drive_unshare_folder(folder_id, permission_id) do
      :ok ->
        emit_drive_acl_event(start_time, :unshare, :ok, attempt, %{
          permission_id: permission_id,
          folder_id: folder_id
        })

        :ok

      {:error, reason} ->
        emit_drive_acl_event(start_time, :unshare, :error, attempt, %{
          permission_id: permission_id,
          folder_id: folder_id,
          error: inspect(reason)
        })

        retry(:unshare, reason, attempt, fn ->
          do_unshare(folder_id, permission_id, attempt + 1)
        end)
    end
  end

  defp retry(_op, _reason, attempt, _fun) when attempt > @max_attempts do
    Logger.error("Drive permission worker exceeded retries (attempt=#{attempt})")
    :error
  end

  defp retry(op, reason, attempt, fun) do
    Logger.warning("Drive permission #{op} failed on attempt #{attempt}: #{inspect(reason)}")

    Process.sleep(backoff_ms() * attempt)
    fun.()
  end

  defp do_revoke_email(folder_id, email, attempt) do
    start_time = System.monotonic_time()

    case Integrations.drive_list_permissions(folder_id) do
      {:ok, permissions} ->
        emit_drive_acl_event(start_time, :permission_lookup, :ok, attempt, %{
          email: email,
          folder_id: folder_id
        })

        case find_permission_id(permissions, email) do
          nil -> :ok
          permission_id -> do_unshare(folder_id, permission_id, 1)
        end

      {:error, reason} ->
        emit_drive_acl_event(start_time, :permission_lookup, :error, attempt, %{
          email: email,
          folder_id: folder_id,
          error: inspect(reason)
        })

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

  defp backoff_ms do
    Application.get_env(
      :dashboard_ssd,
      :drive_permission_worker_backoff_ms,
      @base_backoff
    )
  end

  defp emit_drive_acl_event(start_time, operation, status, attempt, extra) do
    duration = System.monotonic_time() - start_time
    failure = if status == :error, do: 1, else: 0

    metadata =
      %{operation: operation, status: status, attempt: attempt}
      |> Map.merge(extra)

    :telemetry.execute(
      [:dashboard_ssd, :drive_acl, :sync],
      %{duration: duration, failure: failure},
      metadata
    )
  end

  defp access_param(map, keys) do
    Enum.find_value(keys, fn key -> Map.get(map, key) end)
  end
end
