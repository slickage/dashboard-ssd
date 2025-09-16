defmodule DashboardSSDWeb.ClientsLive.FormComponent do
  @moduledoc "LiveComponent for creating and editing clients."
  use DashboardSSDWeb, :live_component
  alias DashboardSSD.Clients

  @impl true
  @doc "Update the form component assigns and initialize the changeset."
  def update(assigns, socket) do
    socket = assign(socket, assigns)
    client = Map.get(socket.assigns, :client) || client_from_action(socket.assigns)
    socket = assign(socket, :client, client)
    {:ok, assign(socket, :changeset, change(client))}
  end

  defp client_from_action(%{action: :new}), do: %Clients.Client{}

  defp client_from_action(%{action: :edit, client_id: id}) when is_binary(id),
    do: Clients.get_client!(String.to_integer(id))

  defp client_from_action(%{action: :edit, client_id: id}) when is_integer(id),
    do: Clients.get_client!(id)

  @impl true
  @doc "Handle client form events (validate/save)."
  def handle_event(event, params, socket)

  def handle_event("validate", %{"client" => params}, socket) do
    {:noreply, assign(socket, :changeset, change(socket.assigns.client, params))}
  end

  def handle_event("save", %{"client" => params}, socket) do
    if admin?(socket.assigns.current_user) do
      save(socket, socket.assigns.action, params)
    else
      {:noreply, put_flash(socket, :error, "Forbidden")}
    end
  end

  defp save(socket, :new, params) do
    case Clients.create_client(params) do
      {:ok, _client} ->
        {:noreply,
         socket
         |> put_flash(:info, "Client created")
         |> push_patch(to: socket.assigns.patch)}

      {:error, cs} ->
        {:noreply, assign(socket, :changeset, cs)}
    end
  end

  defp save(socket, :edit, params) do
    case Clients.update_client(socket.assigns.client, params) do
      {:ok, _client} ->
        {:noreply,
         socket
         |> put_flash(:info, "Client updated")
         |> push_patch(to: socket.assigns.patch)}

      {:error, cs} ->
        {:noreply, assign(socket, :changeset, cs)}
    end
  end

  defp change(client, params \\ %{}), do: Clients.change_client(client, params)

  defp admin?(user), do: user && user.role && user.role.name == "admin"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-4">
      <h2 class="text-lg font-medium">{if @action == :new, do: "New Client", else: "Edit Client"}</h2>
      <.simple_form
        :let={f}
        for={@changeset}
        id="client-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={f[:name]} label="Name" />
        <:actions>
          <.button>Save</.button>
          <.link patch={@patch} class="ml-2 text-zinc-700">Cancel</.link>
        </:actions>
      </.simple_form>
    </div>
    """
  end
end
