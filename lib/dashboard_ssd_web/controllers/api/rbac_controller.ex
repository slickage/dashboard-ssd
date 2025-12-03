defmodule DashboardSSDWeb.API.RBACController do
  @moduledoc "API endpoints for managing role-to-capability assignments."
  use DashboardSSDWeb, :controller

  alias DashboardSSD.Accounts
  alias DashboardSSD.Accounts.Role
  alias DashboardSSD.Auth.Capabilities
  alias Plug.Conn

  @doc "Return all roles with their granted capabilities."
  @spec index(Conn.t(), map()) :: Conn.t()
  def index(conn, _params) do
    data =
      Accounts.role_capability_summary()
      |> Enum.map(&serialize_summary/1)

    json(conn, %{data: data})
  end

  @doc "Replace the capability list for the given role."
  @spec update(Conn.t(), map()) :: Conn.t()
  def update(%Conn{params: %{"role_name" => role_name}} = conn, params) do
    with {:ok, role} <- fetch_role(role_name),
         {:ok, capabilities} <- normalize_capabilities(Map.get(params, "capabilities", [])),
         {:ok, _} <-
           Accounts.replace_role_capabilities(role, capabilities,
             granted_by_id: conn.assigns[:current_user] && conn.assigns.current_user.id
           ) do
      summary =
        Accounts.role_capability_summary()
        |> Enum.find(fn %{role: %Role{name: name}} -> name == role.name end)
        |> serialize_summary()

      json(conn, summary)
    else
      {:error, :invalid_role} ->
        conn |> put_status(:not_found) |> json(%{error: "Unknown role"})

      {:error, {:invalid_capability, code}} ->
        conn |> put_status(:bad_request) |> json(%{error: "Unknown capability #{code}"})

      {:error, :missing_required_admin_capability} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Admin roles must retain required capabilities"})

      {:error, reason} ->
        conn |> put_status(:bad_request) |> json(%{error: inspect(reason)})
    end
  end

  @doc "Reset all roles to their default capability assignments."
  @spec reset(Conn.t(), map()) :: Conn.t()
  def reset(conn, _params) do
    defaults = Capabilities.default_assignments()

    Enum.each(defaults, fn {role_name, capability_codes} ->
      Accounts.replace_role_capabilities(role_name, capability_codes,
        granted_by_id: conn.assigns[:current_user] && conn.assigns.current_user.id
      )
    end)

    send_resp(conn, :accepted, "Capabilities reset to defaults")
  end

  defp fetch_role(role_name) do
    case Accounts.get_role_by_name(role_name) do
      %Role{} = role -> {:ok, role}
      _ -> {:error, :invalid_role}
    end
  end

  defp normalize_capabilities(capabilities) when is_list(capabilities) do
    capabilities
    |> Enum.map(&to_string/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
    |> Enum.reduce_while({:ok, []}, fn code, {:ok, acc} ->
      if Capabilities.valid?(code) do
        {:cont, {:ok, [code | acc]}}
      else
        {:halt, {:error, {:invalid_capability, code}}}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      error -> error
    end
  end

  defp normalize_capabilities(_), do: {:ok, []}

  defp serialize_summary(%{
         role: %Role{name: name},
         capabilities: capabilities,
         updated_at: updated_at,
         updated_by: updated_by
       }) do
    %{
      role: name,
      capabilities: Enum.sort(capabilities),
      updated_at: updated_at,
      updated_by:
        if(updated_by,
          do: %{
            id: updated_by.id,
            name: updated_by.name,
            email: updated_by.email
          },
          else: nil
        )
    }
  end
end
