defmodule DashboardSSDWeb.SharedDocumentController do
  use DashboardSSDWeb, :controller

  alias DashboardSSD.Auth.Policy
  alias DashboardSSD.Documents
  alias DashboardSSD.Integrations

  require Logger

  def download(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    with true <- Policy.can?(user, :read, :client_contracts) || {:error, :forbidden},
         {:ok, document} <- Documents.fetch_client_document(user, id),
         {:ok, descriptor} <- Documents.fetch_download_descriptor(document),
         {:ok, env} <- fetch_source(descriptor) do
      send_drive_response(conn, document, env)
    else
      {:error, :forbidden} ->
        conn
        |> put_flash(:error, "You don't have permission to download that document.")
        |> redirect(to: ~p"/clients/contracts")

      {:error, :client_scope_missing} ->
        conn
        |> put_flash(:error, "Your account is not linked to a client.")
        |> redirect(to: ~p"/clients")

      {:error, :not_found} ->
        conn |> send_resp(:not_found, "Document not found")

      {:error, reason} ->
        Logger.warning("Shared document download failed", reason: inspect(reason), id: id)

        conn
        |> put_flash(:error, "We couldn't download that document. Please try again later.")
        |> redirect(to: ~p"/clients/contracts")
    end
  end

  defp fetch_source(%{source: :drive, source_id: file_id}) do
    case Integrations.drive_download_file(file_id) do
      {:ok, %Tesla.Env{status: status} = env} when status in 200..299 -> {:ok, env}
      {:ok, %Tesla.Env{status: status, body: body}} -> {:error, {:http_error, status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_source(%{source: :notion}), do: {:error, :notion_not_supported}

  defp send_drive_response(conn, document, %Tesla.Env{body: body, headers: headers}) do
    mime_type =
      document.mime_type || header_lookup(headers, "content-type") || "application/octet-stream"

    filename = build_filename(document, mime_type)

    conn
    |> put_resp_content_type(mime_type)
    |> put_resp_header("content-disposition", ~s[attachment; filename="#{filename}"])
    |> send_resp(200, body)
  end

  defp header_lookup(headers, key) do
    target = String.downcase(key)

    headers
    |> Enum.find_value(fn
      {k, v} when is_binary(k) ->
        if String.downcase(k) == target, do: v, else: nil

      _ ->
        nil
    end)
  end

  defp build_filename(document, mime_type) do
    base =
      document.title
      |> to_string()
      |> String.trim()
      |> case do
        "" -> "document"
        other -> other
      end
      |> String.replace(~r/\s+/, "_")

    ext =
      mime_type
      |> MIME.extensions()
      |> List.first()

    if ext do
      "#{base}.#{ext}"
    else
      base
    end
  end
end
