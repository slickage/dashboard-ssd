defmodule DashboardSSDWeb.SharedDocumentController do
  @moduledoc """
  Handles proxied downloads for client-facing shared documents.
  """
  use DashboardSSDWeb, :controller

  alias DashboardSSD.Auth.Policy
  alias DashboardSSD.Cache.SharedDocumentsCache
  alias DashboardSSD.Documents
  alias DashboardSSD.Documents.NotionRenderer
  alias DashboardSSD.Integrations

  require Logger
  @max_download_bytes 25 * 1024 * 1024

  @doc """
  Streams the requested shared document to the current client user.
  """
  @spec download(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def download(conn, %{"id" => id}) do
    user = conn.assigns.current_user
    start_time = System.monotonic_time()

    case build_download_request(user, id) do
      {:ok, document, payload} ->
        case deliver_download(conn, document, payload) do
          {:ok, conn} ->
            emit_download_telemetry(start_time, :ok, document, user)
            conn

          {:oversized, conn} ->
            emit_download_telemetry(start_time, :oversized, document, user, %{error: :oversized})
            conn
        end

      {:error, :forbidden} ->
        emit_download_telemetry(start_time, :forbidden, nil, user)

        conn
        |> put_flash(:error, "You don't have permission to download that document.")
        |> redirect(to: ~p"/clients/contracts")

      {:error, :client_scope_missing} ->
        emit_download_telemetry(start_time, :client_scope_missing, nil, user)

        conn
        |> put_flash(:error, "Your account is not linked to a client.")
        |> redirect(to: ~p"/clients")

      {:error, :not_found} ->
        emit_download_telemetry(start_time, :not_found, nil, user)
        send_resp(conn, :not_found, "Document not found")

      {:error, reason} ->
        Logger.warning("Shared document download failed (reason=#{inspect(reason)}, id=#{id})")
        emit_download_telemetry(start_time, :error, nil, user, %{error: inspect(reason)})

        conn
        |> put_flash(:error, "We couldn't download that document. Please try again later.")
        |> redirect(to: ~p"/clients/contracts")
    end
  end

  defp build_download_request(user, id) do
    with true <- Policy.can?(user, :read, :client_contracts) || {:error, :forbidden},
         {:ok, document} <- Documents.fetch_client_document(user, id),
         {:ok, payload} <- fetch_source(document) do
      _ = Documents.log_access(document, user, :download, %{source: document.source})
      {:ok, document, payload}
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

  # sobelow_skip ["XSS.ContentType", "XSS.SendResp"]
  defp deliver_download(conn, document, %{body: body, headers: headers}) do
    case maybe_block_for_size(document, headers, byte_size(body)) do
      :ok ->
        mime_type =
          document.mime_type || header_lookup(headers, "content-type") ||
            "application/octet-stream"

        filename = build_filename(document, mime_type)

        conn =
          conn
          |> put_resp_content_type(mime_type)
          |> put_resp_header("content-disposition", ~s[attachment; filename="#{filename}"])
          |> send_resp(200, body)

        {:ok, conn}

      {:oversized, message} ->
        conn =
          conn
          |> put_flash(:error, message)
          |> redirect(to: ~p"/clients/contracts")

        {:oversized, conn}
    end
  end

  # sobelow_skip ["XSS.ContentType", "XSS.SendResp"]
  defp deliver_download(conn, document, %{body: body, mime_type: mime_type, filename: filename}) do
    case maybe_block_for_size(document, [], byte_size(body)) do
      :ok ->
        conn =
          conn
          |> put_resp_content_type(mime_type || "application/octet-stream")
          |> put_resp_header("content-disposition", ~s[attachment; filename="#{filename}"])
          |> send_resp(200, body)

        {:ok, conn}

      {:oversized, message} ->
        conn =
          conn
          |> put_flash(:error, message)
          |> redirect(to: ~p"/clients/contracts")

        {:oversized, conn}
    end
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

  defp maybe_block_for_size(document, headers, body_size) do
    size =
      header_lookup(headers, "content-length")
      |> parse_int()
      |> case do
        nil -> body_size
        value -> value
      end

    if size > @max_download_bytes do
      {:oversized, oversize_message(document)}
    else
      :ok
    end
  end

  defp parse_int(nil), do: nil

  defp parse_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp oversize_message(%{source: :drive, source_id: source_id}) do
    "This file is larger than #{human_size(@max_download_bytes)}. Open it directly in Drive: #{drive_link(source_id)}"
  end

  defp oversize_message(%{source: :notion, source_id: page_id}) do
    "This document is too large to proxy. View it in Notion instead: #{notion_link(page_id)}"
  end

  defp human_size(bytes) do
    mb = Float.round(bytes / 1_048_576, 1)
    "#{mb} MB"
  end

  defp drive_link(source_id), do: "https://drive.google.com/file/d/#{source_id}/view"
  defp notion_link(page_id), do: "https://www.notion.so/#{page_id}"

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

  defp emit_download_telemetry(start_time, status, document, user, extra \\ %{}) do
    duration = System.monotonic_time() - start_time

    metadata =
      download_metadata(document, user)
      |> Map.put(:status, status)
      |> Map.merge(extra)

    :telemetry.execute([:dashboard_ssd, :documents, :download], %{duration: duration}, metadata)
  end

  defp download_metadata(nil, user) do
    %{
      document_id: nil,
      client_id: nil,
      project_id: nil,
      source: nil,
      user_id: user && user.id,
      user_role: user_role(user)
    }
  end

  defp download_metadata(document, user) do
    %{
      document_id: document.id,
      client_id: document.client_id,
      project_id: document.project_id,
      source: document.source,
      user_id: user && user.id,
      user_role: user_role(user)
    }
  end

  defp user_role(%{role: %{name: name}}), do: name
  defp user_role(_), do: nil
end
