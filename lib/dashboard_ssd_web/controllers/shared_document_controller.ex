defmodule DashboardSSDWeb.SharedDocumentController do
  use DashboardSSDWeb, :controller

  alias DashboardSSD.Auth.Policy
  alias DashboardSSD.Documents
  alias DashboardSSD.Documents.NotionRenderer
  alias DashboardSSD.Cache.SharedDocumentsCache
  alias DashboardSSD.Integrations

  require Logger

  def download(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    with true <- Policy.can?(user, :read, :client_contracts) || {:error, :forbidden},
         {:ok, document} <- Documents.fetch_client_document(user, id),
         {:ok, payload} <- fetch_source(document) do
      _ = Documents.log_access(document, user, :download, %{source: document.source})
      deliver_download(conn, document, payload)
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

  defp fetch_source(%{source: :drive} = document) do
    SharedDocumentsCache.fetch_download_descriptor(document.id, fn ->
      case Integrations.drive_download_file(document.source_id) do
        {:ok, %Tesla.Env{status: status, body: body, headers: headers}} when status in 200..299 ->
          {:ok, %{payload: %{body: body, headers: headers}}}

        {:ok, %Tesla.Env{status: status, body: body}} ->
          {:error, {:http_error, status, body}}

        {:error, reason} ->
          {:error, reason}
      end
    end)
    |> unwrap_payload()
  end

  defp fetch_source(%{source: :notion} = document) do
    case NotionRenderer.render_download(document.source_id) do
      {:ok, payload} ->
        {:ok, %{body: payload.data, mime_type: payload.mime_type, filename: payload.filename}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp deliver_download(conn, document, %{body: body, headers: headers}) do
    mime_type =
      document.mime_type || header_lookup(headers, "content-type") || "application/octet-stream"

    filename = build_filename(document, mime_type)

    conn
    |> put_resp_content_type(mime_type)
    |> put_resp_header("content-disposition", ~s[attachment; filename="#{filename}"])
    |> send_resp(200, body)
  end

  defp deliver_download(conn, _document, %{body: body, mime_type: mime_type, filename: filename}) do
    conn
    |> put_resp_content_type(mime_type || "application/octet-stream")
    |> put_resp_header("content-disposition", ~s[attachment; filename="#{filename}"])
    |> send_resp(200, body)
  end

  defp header_lookup(headers, key) do
    target = String.downcase(key)

    Enum.find_value(headers, fn
      {k, v} when is_binary(k) ->
        if String.downcase(k) == target, do: v, else: nil

      _ ->
        nil
    end)
  end

  defp unwrap_payload({:ok, %{payload: payload}}), do: {:ok, payload}
  defp unwrap_payload(other), do: other

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
