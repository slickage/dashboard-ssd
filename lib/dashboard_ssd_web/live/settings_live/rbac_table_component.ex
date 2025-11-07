defmodule DashboardSSDWeb.SettingsLive.RbacTableComponent do
  @moduledoc "LiveComponent for displaying and editing role capability assignments."
  use DashboardSSDWeb, :live_component

  attr :roles, :list, required: true
  attr :catalog, :list, required: true
  attr :current_user, :map, required: true

  @immutable_capabilities %{
    "admin" => ["settings.rbac"]
  }

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div class="space-y-6" data-role="rbac-settings-table">
      <div class="flex items-center justify-between">
        <p class="text-sm text-theme-text-muted">
          {gettext(
            "Toggle capabilities to grant or revoke access per role. Required permissions are locked."
          )}
        </p>
        <form phx-submit="reset_capabilities" data-role="rbac-reset-form">
          <.button
            type="submit"
            class="btn-secondary"
            phx-disable-with={gettext("Restoring…")}
            phx-confirm={gettext("Reset all roles to their default capabilities?")}
          >
            {gettext("Restore defaults")}
          </.button>
        </form>
      </div>

      <%= for %{role: role} <- @roles do %>
        <form
          id={"rbac-form-#{role.name}"}
          phx-change="update_capabilities"
          phx-submit="update_capabilities"
          data-role="rbac-role-form"
          data-role-name={role.name}
        >
          <input type="hidden" name="role" value={role.name} />
        </form>
      <% end %>

      <div class="overflow-x-auto">
        <table class="theme-table">
          <thead>
            <tr>
              <th class="w-32">{gettext("Role")}</th>
              <%= for capability <- @catalog do %>
                <th class="text-center" title={capability.description}>{capability.label}</th>
              <% end %>
              <th class="w-48">{gettext("Last updated")}</th>
            </tr>
          </thead>
          <tbody>
            <%= for %{role: role, capabilities: capabilities, updated_at: updated_at, updated_by: updated_by} <- @roles do %>
              <tr>
                <td class="font-semibold capitalize">{role.name}</td>
                <td :for={capability <- @catalog} class="text-center">
                  <% immutable? = immutable_capability?(role.name, capability.code) %>
                  <label class="inline-flex items-center justify-center gap-2">
                    <input
                      type="checkbox"
                      name="capabilities[]"
                      value={capability.code}
                      checked={capability.code in capabilities}
                      form={"rbac-form-#{role.name}"}
                      class={[
                        "h-4 w-4 rounded border-theme-border bg-theme-surface text-theme-primary focus:ring-theme-primary",
                        immutable? && "opacity-40 cursor-not-allowed"
                      ]}
                      disabled={immutable?}
                      aria-disabled={if immutable?, do: "true", else: "false"}
                      title={
                        if immutable?,
                          do: gettext("Required capability"),
                          else: capability.description
                      }
                    />
                    <.icon
                      :if={immutable?}
                      name="hero-lock-closed-mini"
                      class="h-4 w-4 text-theme-text-muted"
                    />
                  </label>
                  <%= if immutable? do %>
                    <input
                      type="hidden"
                      name="capabilities[]"
                      value={capability.code}
                      form={"rbac-form-#{role.name}"}
                    />
                  <% end %>
                </td>
                <td class="text-sm text-theme-text-muted">
                  <%= if updated_at do %>
                    <div>{Calendar.strftime(updated_at, "%Y-%m-%d %H:%M")}</div>
                    <%= if updated_by do %>
                      <div>{gettext("by %{name}", name: updated_by.name || updated_by.email)}</div>
                    <% end %>
                  <% else %>
                    <span>{gettext("Never")}</span>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp immutable_capability?(role_name, capability_code) do
    capability_code in Map.get(@immutable_capabilities, role_name, [])
  end
end
