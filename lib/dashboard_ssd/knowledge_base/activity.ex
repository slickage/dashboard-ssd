defmodule DashboardSSD.KnowledgeBase.Activity do
  @moduledoc """
  Persists and retrieves knowledge base activity (e.g., recently viewed documents).

    - Records KB view events into the audits table with normalized metadata.
  - Provides recent-document lookup utilities for user dashboards.
  - Handles metadata normalization and guards against DB connection errors.
  """

  import Ecto.Query

  alias DashboardSSD.KnowledgeBase.Types
  alias DashboardSSD.Repo
  alias DBConnection.ConnectionError

  @action "kb.viewed"
  @default_limit 5

  @typedoc "Options for recording a view."
  @type record_opt ::
          {:metadata, map()}
          | {:occurred_at, DateTime.t() | NaiveDateTime.t()}
          | {:timestamp, DateTime.t() | NaiveDateTime.t()}

  @typedoc "Options for recent document lookups."
  @type recent_opt :: {:limit, pos_integer()} | {:include_deleted?, boolean()}

  @doc """
  Records a knowledge base view event.
  """
  @spec record_view(map() | term(), map(), [record_opt()]) :: :ok | {:error, term()}
  def record_view(user_attrs, document_attrs, opts \\ []) do
    with {:ok, user_id} <- fetch_user_id(user_attrs),
         {:ok, document_id} <- fetch_document_id(document_attrs) do
      metadata = opts |> Keyword.get(:metadata, %{}) |> normalize_metadata()

      details =
        %{
          "document_id" => document_id,
          "document_title" => attr_value(document_attrs, :document_title),
          "document_icon" => attr_value(document_attrs, :document_icon),
          "document_share_url" => attr_value(document_attrs, :document_share_url)
        }
        |> Map.merge(metadata)
        |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
        |> Map.new()

      entry = %{
        user_id: user_id,
        action: @action,
        details: details,
        inserted_at: opts |> Keyword.get(:occurred_at, opts[:timestamp]) |> normalize_timestamp()
      }

      try do
        {1, _} = Repo.insert_all("audits", [entry])
        :ok
      rescue
        e in ConnectionError -> {:error, e}
        e in Postgrex.Error -> {:error, e}
      end
    end
  end

  @doc """
  Fetches recently viewed documents for a user.
  """
  @spec recent_documents(term(), [recent_opt()]) ::
          {:ok, [Types.RecentActivity.t()]} | {:error, term()}
  def recent_documents(user_attrs, opts \\ []) do
    with {:ok, user_id} <- fetch_user_id(user_attrs) do
      limit = opts |> Keyword.get(:limit, @default_limit) |> normalize_limit()

      query =
        from a in "audits",
          where: a.user_id == ^user_id and a.action == ^@action,
          order_by: [desc: a.inserted_at],
          limit: 50,
          select: %{details: a.details, occurred_at: a.inserted_at}

      activities =
        query
        |> Repo.all()
        |> Enum.map(&to_recent_activity(user_id, &1))
        |> dedupe_recent_documents()
        |> Enum.take(limit)

      {:ok, activities}
    end
  end

  defp fetch_user_id(%{id: id}) when is_integer(id), do: {:ok, id}
  defp fetch_user_id(%{"id" => id}) when is_integer(id), do: {:ok, id}
  defp fetch_user_id(%{user_id: id}) when is_integer(id), do: {:ok, id}
  defp fetch_user_id(%{"user_id" => id}) when is_integer(id), do: {:ok, id}
  defp fetch_user_id(id) when is_integer(id), do: {:ok, id}
  defp fetch_user_id(_), do: {:error, :invalid_user}

  defp fetch_document_id(%{document_id: id}) when is_binary(id), do: {:ok, id}
  defp fetch_document_id(%{"document_id" => id}) when is_binary(id), do: {:ok, id}
  defp fetch_document_id(%{document_id: id}) when is_integer(id), do: {:ok, Integer.to_string(id)}

  defp fetch_document_id(%{"document_id" => id}) when is_integer(id),
    do: {:ok, Integer.to_string(id)}

  defp fetch_document_id(attrs) when is_list(attrs) do
    attrs
    |> Enum.into(%{})
    |> fetch_document_id()
  end

  defp fetch_document_id(_), do: {:error, :invalid_document}

  defp attr_value(map, key) when is_map(map) do
    map[key] || map[to_string(key)]
  end

  defp attr_value(map, key) when is_list(map) do
    map
    |> Enum.into(%{})
    |> attr_value(key)
  end

  defp attr_value(_map, _key), do: nil

  defp normalize_timestamp(nil),
    do: DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_naive()

  defp normalize_timestamp(%DateTime{} = dt),
    do: dt |> DateTime.truncate(:second) |> DateTime.to_naive()

  defp normalize_timestamp(%NaiveDateTime{} = ndt), do: NaiveDateTime.truncate(ndt, :second)

  defp normalize_timestamp(other) when is_binary(other) do
    case NaiveDateTime.from_iso8601(other) do
      {:ok, ndt} -> ndt
      _ -> normalize_timestamp(nil)
    end
  end

  defp normalize_timestamp(_), do: normalize_timestamp(nil)

  defp normalize_metadata(meta) when is_map(meta) do
    meta
    |> Enum.into(%{})
    |> Map.new(fn {k, v} -> {to_string(k), v} end)
    |> Map.drop(["document_id", "document_title", "document_share_url"])
  end

  defp normalize_metadata(_), do: %{}

  defp normalize_limit(limit) when is_integer(limit) and limit > 0, do: limit
  defp normalize_limit(_), do: @default_limit

  defp to_recent_activity(user_id, %{details: details, occurred_at: occurred_at}) do
    details = details || %{}

    %Types.RecentActivity{
      user_id: user_id,
      document_id: details["document_id"] || details[:document_id],
      document_title: details["document_title"] || details[:document_title],
      document_icon: details["document_icon"] || details[:document_icon],
      document_share_url: details["document_share_url"] || details[:document_share_url],
      occurred_at: convert_to_datetime(occurred_at),
      metadata:
        details
        |> Enum.into(%{})
        |> Map.drop([
          "document_id",
          :document_id,
          "document_title",
          :document_title,
          "document_icon",
          :document_icon,
          "document_share_url",
          :document_share_url
        ])
    }
  end

  defp convert_to_datetime(%DateTime{} = dt), do: dt
  defp convert_to_datetime(%NaiveDateTime{} = ndt), do: DateTime.from_naive!(ndt, "Etc/UTC")

  defp convert_to_datetime(value) when is_binary(value) do
    case NaiveDateTime.from_iso8601(value) do
      {:ok, ndt} -> DateTime.from_naive!(ndt, "Etc/UTC")
      _ -> DateTime.utc_now()
    end
  end

  defp dedupe_recent_documents(activities) do
    Enum.uniq_by(activities, & &1.document_id)
  end
end
