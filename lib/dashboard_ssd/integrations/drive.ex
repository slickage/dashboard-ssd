defmodule DashboardSSD.Integrations.Drive do
  @moduledoc """
  Google Drive helper client that wraps the small subset of APIs used by
  Shared Documents (listing folders/files, ensuring project folders exist,
  sharing/unsharing folders, and proxying downloads).
  """
  use Tesla

  @base "https://www.googleapis.com/drive/v3"
  @folder_mime "application/vnd.google-apps.folder"
  @default_listing_fields "nextPageToken, files(id,name,mimeType,size,modifiedTime,webViewLink,permissions,appProperties)"

  plug Tesla.Middleware.BaseUrl, @base
  plug Tesla.Middleware.Query
  plug Tesla.Middleware.Headers, [{"content-type", "application/json"}]
  plug Tesla.Middleware.JSON

  @doc """
  Lists raw files within the folder. Superseded by `list_documents/1` but kept
  for backward compatibility.
  """
  @spec list_files_in_folder(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def list_files_in_folder(token, folder_id) do
    list_documents(%{token: token, folder_id: folder_id})
  end

  @doc """
  Ensures that a folder named `opts.name` exists under `opts.parent_id`.
  Creates the folder when missing and returns its metadata.
  """
  @spec ensure_project_folder(String.t(), %{
          required(:parent_id) => String.t(),
          required(:name) => String.t(),
          optional(:description) => String.t(),
          optional(:properties) => map()
        }) ::
          {:ok, map()} | {:error, term()}
  def ensure_project_folder(token, %{parent_id: parent_id, name: name} = opts)
      when is_binary(parent_id) and parent_id != "" and is_binary(name) and name != "" do
    with {:ok, existing} <- find_folder(token, parent_id, name) do
      case existing do
        nil -> create_folder(token, parent_id, name, opts)
        folder -> {:ok, folder}
      end
    end
  end

  def ensure_project_folder(_, _), do: {:error, :invalid_folder_arguments}

  @doc """
  Lists all documents inside a Drive folder, traversing pagination until
  every file is returned.
  """
  @spec list_documents(%{
          required(:token) => String.t(),
          required(:folder_id) => String.t(),
          optional(:fields) => String.t(),
          optional(:page_size) => pos_integer()
        }) ::
          {:ok, map()} | {:error, term()}
  def list_documents(%{token: token, folder_id: folder_id} = opts)
      when is_binary(folder_id) and folder_id != "" do
    fields = Map.get(opts, :fields, @default_listing_fields)
    page_size = Map.get(opts, :page_size, 100)

    fetch_documents(token, folder_id, fields, page_size, [])
  end

  def list_documents(_), do: {:error, :invalid_arguments}

  @doc """
  Shares a folder with the provided target (user/group/domain) and role.
  """
  @spec share_folder(String.t(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def share_folder(token, folder_id, params) do
    role = Map.get(params, :role) || Map.get(params, "role")

    unless role do
      raise ArgumentError, "share_folder/3 requires :role"
    end

    type = Map.get(params, :type, Map.get(params, "type", "user"))
    email = params[:email] || params["email"] || params[:email_address] || params["email_address"]

    body =
      %{
        role: role,
        type: type,
        allowFileDiscovery: Map.get(params, :allow_file_discovery, false)
      }
      |> maybe_put_email(type, email)

    query = [
      supportsAllDrives: true,
      sendNotificationEmail: Map.get(params, :send_notification_email?, false)
    ]

    "/files/#{folder_id}/permissions"
    |> post(body, query: query, headers: auth_headers(token))
    |> handle_response()
  end

  @doc """
  Removes a previously granted permission entry from the folder.
  """
  @spec unshare_folder(String.t(), String.t(), String.t()) :: :ok | {:error, term()}
  def unshare_folder(token, folder_id, permission_id) do
    "/files/#{folder_id}/permissions/#{permission_id}"
    |> delete(query: support_all_drives(), headers: auth_headers(token))
    |> case do
      {:ok, %Tesla.Env{status: status}} when status in 200..299 -> :ok
      {:ok, %Tesla.Env{status: status, body: body}} -> {:error, {:http_error, status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Lists permission entries for the folder/file to help identify granted emails.
  """
  @spec list_permissions(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def list_permissions(token, folder_id) do
    query =
      support_all_drives()
      |> Keyword.merge(fields: "permissions(id,emailAddress,role,type)")

    "/files/#{folder_id}/permissions"
    |> get(query: query, headers: auth_headers(token))
    |> handle_response()
  end

  @doc """
  Downloads the file content via Drive's media endpoint.
  """
  @spec download_file(String.t(), String.t()) :: {:ok, Tesla.Env.t()} | {:error, term()}
  def download_file(token, file_id) do
    "/files/#{file_id}"
    |> get(
      query: [alt: "media", supportsAllDrives: true],
      headers: auth_headers(token),
      opts: [decode: false]
    )
    |> case do
      {:ok, %Tesla.Env{status: status} = env} when status in 200..299 -> {:ok, env}
      {:ok, %Tesla.Env{status: status, body: body}} -> {:error, {:http_error, status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_documents(access_token, folder_id, fields, page_size, acc, page_token \\ nil) do
    query =
      [
        q: folder_files_query(folder_id),
        fields: fields,
        pageSize: page_size,
        pageToken: page_token
      ]
      |> Keyword.merge(support_all_drives())
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)

    case get("/files", query: query, headers: auth_headers(access_token)) do
      {:ok, %Tesla.Env{status: 200, body: %{"files" => files} = body}} ->
        merged = acc ++ files

        case Map.get(body, "nextPageToken") do
          nil ->
            {:ok, %{"files" => merged}}

          next_page_token ->
            fetch_documents(access_token, folder_id, fields, page_size, merged, next_page_token)
        end

      other ->
        handle_response(other)
    end
  end

  defp find_folder(token, parent_id, name) do
    query =
      [
        q:
          "name = '#{escape_query(name)}' and '#{parent_id}' in parents and mimeType = '#{@folder_mime}' and trashed = false",
        fields: "files(id,name,parents,webViewLink)",
        pageSize: 1
      ]
      |> Keyword.merge(support_all_drives())

    case get("/files", query: query, headers: auth_headers(token)) do
      {:ok, %Tesla.Env{status: 200, body: %{"files" => [folder | _]}}} -> {:ok, folder}
      {:ok, %Tesla.Env{status: 200, body: %{"files" => []}}} -> {:ok, nil}
      other -> handle_response(other)
    end
  end

  defp create_folder(token, parent_id, name, opts) do
    body =
      %{
        name: name,
        parents: [parent_id],
        mimeType: @folder_mime,
        description: Map.get(opts, :description)
      }
      |> maybe_put_properties(Map.get(opts, :properties))

    "/files"
    |> post(body, query: support_all_drives(), headers: auth_headers(token))
    |> handle_response()
  end

  defp folder_files_query(folder_id) do
    "'#{escape_query(folder_id)}' in parents and trashed = false"
  end

  defp support_all_drives do
    [supportsAllDrives: true, includeItemsFromAllDrives: true]
  end

  defp maybe_put_properties(body, nil), do: body

  defp maybe_put_properties(body, props) when is_map(props),
    do: Map.put(body, :appProperties, props)

  defp maybe_put_email(body, type, email) when type in ["user", "group"] do
    if is_binary(email) and email != "" do
      Map.put(body, :emailAddress, email)
    else
      raise ArgumentError, "share_folder/3 requires email for type=#{type}"
    end
  end

  defp maybe_put_email(body, _type, _email), do: body

  defp auth_headers(token), do: [{"authorization", "Bearer #{token}"}]

  defp handle_response({:ok, %Tesla.Env{status: status, body: body}}) when status in 200..299,
    do: {:ok, body}

  defp handle_response({:ok, %Tesla.Env{status: status, body: body}}),
    do: {:error, {:http_error, status, body}}

  defp handle_response({:error, reason}), do: {:error, reason}

  defp escape_query(value) do
    value
    |> String.replace("\\", "\\\\")
    |> String.replace("'", "\\'")
  end
end
