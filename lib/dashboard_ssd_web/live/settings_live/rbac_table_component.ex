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
    <section class="theme-card p-6" data-role="rbac-settings">
      <header class="flex items-center justify-between">
        <div>
          <h2 class="text-xl font-semibold text-theme-text">RBAC Settings</h2>
          <p class="text-sm text-theme-text-muted">
            Control which capabilities each role can access.
          </p>
        </div>
        <form phx-submit="reset_capabilities" data-role="rbac-reset-form" class="flex items-center">
          <button
            type="submit"
            class="rounded-full border border-white/10 bg-white/5 px-4 py-2 text-xs font-semibold uppercase tracking-[0.18em] text-white transition hover:border-white/20 hover:bg-white/10"
          >
            Restore defaults
          </button>
        </form>
      </header>

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

      <div class="mt-6 overflow-x-auto">
        <table class="theme-table">
          <thead>
            <tr>
              <th class="w-32">Role</th>
              <%= for capability <- @catalog do %>
                <th class="text-center" title={capability.description}>{capability.label}</th>
              <% end %>
              <th class="w-48">Last Updated</th>
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
                      class="h-4 w-4 rounded border-theme-border bg-theme-surface text-theme-primary focus:ring-theme-primary disabled:opacity-50"
                      disabled={immutable?}
                      aria-disabled={if immutable?, do: "true", else: "false"}
                      title={if immutable?, do: "Required capability", else: nil}
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
                      <div>by {updated_by.name || updated_by.email}</div>
                    <% end %>
                  <% else %>
                    <span>Never</span>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </section>
    """
  end

  defp immutable_capability?(role_name, capability_code) do
    capability_code in Map.get(@immutable_capabilities, role_name, [])
  end
end
