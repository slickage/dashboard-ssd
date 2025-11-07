defmodule DashboardSSD.Integrations.FirefliesClient do
  @moduledoc """
  Fireflies.ai GraphQL client for querying meeting artifacts (bites, summaries).

  Authentication: Bearer token via `FIREFLIES_API_TOKEN` loaded into
  `Application.get_env(:dashboard_ssd, :integrations)[:fireflies_api_token]`.

  This module avoids logging secrets and returns normalized `{:ok, ...}` / `{:error, ...}` tuples.
  """

  use Tesla
  require Logger

  @base "https://api.fireflies.ai/graphql"

  plug Tesla.Middleware.BaseUrl, @base
  plug Tesla.Middleware.JSON

  @type bite :: map()

  @doc """
  Lists bites with optional filters.

  Options:
    * `:mine` - boolean; filter to the API key owner (default: true)
    * `:my_team` - boolean; filter to the team of the API key owner
    * `:transcript_id` - ID; list bites for a specific transcript
    * `:limit` - integer; max 50
    * `:skip` - integer; offset for pagination

  Returns `{:ok, [bite]}` or `{:error, reason}`.
  """
  @spec list_bites(keyword()) :: {:ok, [bite()]} | {:error, term()}
  def list_bites(opts \\ []) do
    with {:ok, token} <- token() do
      query = """
      query Bites($limit: Int, $skip: Int, $transcript_id: ID, $mine: Boolean, $my_team: Boolean) {
        bites(limit: $limit, skip: $skip, transcript_id: $transcript_id, mine: $mine, my_team: $my_team) {
          id
          transcript_id
          name
          status
          summary
          start_time
          end_time
          summary_status
          media_type
          created_at
          created_from { id name type description duration }
        }
      }
      """

      variables =
        %{
          "limit" => clamp(Keyword.get(opts, :limit)),
          "skip" => Keyword.get(opts, :skip),
          "transcript_id" => Keyword.get(opts, :transcript_id),
          "mine" => Keyword.get(opts, :mine, true),
          "my_team" => Keyword.get(opts, :my_team)
        }
        |> drop_nils()

      case post_graphql(token, query, variables) do
        {:ok, %{"data" => %{"bites" => bites}}} when is_list(bites) -> {:ok, bites}
        {:ok, %{"errors" => errs}} -> handle_graphql_errors(errs)
        {:ok, _other} -> {:ok, []}
        {:error, {:http_error, status, body}} -> handle_http_error(status, body)
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Retrieves a single bite by ID with common fields.
  """
  @spec get_bite(String.t()) :: {:ok, bite()} | {:error, term()}
  def get_bite(bite_id) when is_binary(bite_id) do
    with {:ok, token} <- token() do
      query = """
      query Bite($biteId: ID!) {
        bite(id: $biteId) {
          id
          transcript_id
          name
          status
          summary
          start_time
          end_time
          summary_status
          media_type
          created_at
          created_from { id name type description duration }
        }
      }
      """

      case post_graphql(token, query, %{"biteId" => bite_id}) do
        {:ok, %{"data" => %{"bite" => bite}}} when is_map(bite) -> {:ok, bite}
        {:ok, %{"errors" => errs}} -> handle_graphql_errors(errs)
        {:ok, _other} -> {:error, :not_found}
        {:error, {:http_error, status, body}} -> handle_http_error(status, body)
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Retrieves summary information for a transcript (via bites).

  Returns a map with keys:
    * `:notes` - text from the bite summary when available
    * `:action_items` - currently an empty list (AI Apps integration to be added)
    * `:bullet_gist` - always nil for bites path (not provided on this query)
  """
  @spec get_summary_for_transcript(String.t()) ::
          {:ok,
           %{notes: String.t() | nil, action_items: [String.t()], bullet_gist: String.t() | nil}}
          | {:error, term()}
  def get_summary_for_transcript(transcript_id) when is_binary(transcript_id) do
    with {:ok, token} <- token() do
      query = """
      query TranscriptBites($transcript_id: ID!, $limit: Int) {
        bites(transcript_id: $transcript_id, limit: $limit) {
          id
          transcript_id
          summary
          end_time
        }
      }
      """

      variables = %{"transcript_id" => transcript_id, "limit" => 1}

      case post_graphql(token, query, variables) do
        {:ok, %{"data" => %{"bites" => [bite | _]}}} ->
          {:ok, %{notes: Map.get(bite, "summary"), action_items: [], bullet_gist: nil}}

        {:ok, %{"errors" => errs}} -> handle_graphql_errors(errs)
        {:ok, _other} -> {:ok, %{notes: nil, action_items: [], bullet_gist: nil}}
        {:error, {:http_error, status, body}} -> handle_http_error(status, body)
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Lists transcripts with optional filters and includes summary fields.

  Options (subset, subject to Fireflies API constraints):
    * `:mine` - boolean; filter to API key owner
    * `:organizers` - [String]
    * `:participants` - [String]
    * `:from_date` - ISO 8601 string
    * `:to_date` - ISO 8601 string
    * `:limit` - integer (max 50)
    * `:skip` - integer
  """
  @spec list_transcripts(keyword()) :: {:ok, [map()]} | {:error, term()}
  def list_transcripts(opts \\ []) do
    with {:ok, token} <- token() do
      query = """
      query Transcripts(
        $mine: Boolean,
        $userId: String,
        $hostEmail: String,
        $organizerEmail: String,
        $participantEmail: String,
        $organizers: [String!],
        $participants: [String!],
        $fromDate: DateTime,
        $toDate: DateTime,
        $limit: Int,
        $skip: Int
      ) {
        transcripts(
          mine: $mine,
          user_id: $userId,
          host_email: $hostEmail,
          organizer_email: $organizerEmail,
          participant_email: $participantEmail,
          organizers: $organizers,
          participants: $participants,
          fromDate: $fromDate,
          toDate: $toDate,
          limit: $limit,
          skip: $skip
        ) {
          id
          title
          date
          summary {
            action_items
            overview
            short_summary
            short_overview
            bullet_gist
          }
        }
      }
      """

      # Respect Fireflies exclusivity: only one of mine, userId, hostEmail, organizerEmail, participantEmail may be set.
      exclusives =
        %{
          "userId" => Keyword.get(opts, :user_id),
          "hostEmail" => Keyword.get(opts, :host_email),
          "organizerEmail" => Keyword.get(opts, :organizer_email),
          "participantEmail" => Keyword.get(opts, :participant_email)
        }
        |> drop_nils()

      # Determine default exclusive: prefer configured user_id when none provided
      # and :mine is not explicitly set; otherwise fallback to mine=true.
      cfg_user = configured_user_id()

      {mine_opt, user_opt} =
        if map_size(exclusives) == 0 do
          cond do
            Keyword.has_key?(opts, :mine) -> {Keyword.get(opts, :mine), nil}
            is_binary(cfg_user) and String.trim(cfg_user) != "" -> {nil, cfg_user}
            true -> {true, nil}
          end
        else
          {nil, nil}
        end

      variables =
        %{
          "mine" => mine_opt,
          "userId" => Map.get(exclusives, "userId") || user_opt,
          "hostEmail" => Map.get(exclusives, "hostEmail"),
          "organizerEmail" => Map.get(exclusives, "organizerEmail"),
          "participantEmail" => Map.get(exclusives, "participantEmail"),
          "organizers" => sanitize_string_list(Keyword.get(opts, :organizers)),
          "participants" => sanitize_string_list(Keyword.get(opts, :participants)),
          "fromDate" => Keyword.get(opts, :from_date),
          "toDate" => Keyword.get(opts, :to_date),
          "limit" => clamp(Keyword.get(opts, :limit, 10)),
          "skip" => Keyword.get(opts, :skip)
        }
        |> drop_nils()

      case post_graphql(token, query, variables) do
        {:ok, %{"data" => %{"transcripts" => list}}} when is_list(list) -> {:ok, list}
        {:ok, %{"errors" => errs}} -> handle_graphql_errors(errs)
        {:ok, _} -> {:ok, []}
        {:error, {:http_error, status, body}} -> handle_http_error(status, body)
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Retrieves a single transcript with summary fields.
  Returns {:ok, %{notes: text | nil, action_items: [String], bullet_gist: String | nil}}.
  Notes prefer `summary.overview` then `summary.short_summary`.
  """
  @spec get_transcript_summary(String.t()) ::
          {:ok,
           %{notes: String.t() | nil, action_items: [String.t()], bullet_gist: String.t() | nil}}
          | {:error, term()}
  def get_transcript_summary(transcript_id) when is_binary(transcript_id) do
    with {:ok, token} <- token() do
      query = """
      query Transcript($transcriptId: String!) {
        transcript(id: $transcriptId) {
          id
          title
          summary {
            action_items
            overview
            short_summary
            bullet_gist
          }
        }
      }
      """

      case post_graphql(token, query, %{"transcriptId" => transcript_id}) do
        {:ok, %{"data" => %{"transcript" => %{"summary" => summary}}}} when is_map(summary) ->
          action_items = Map.get(summary, "action_items") || []
          notes = Map.get(summary, "overview") || Map.get(summary, "short_summary")
          bullet_gist = Map.get(summary, "bullet_gist")
          {:ok, %{notes: notes, action_items: action_items, bullet_gist: bullet_gist}}

        {:ok, %{"errors" => errs}} -> handle_graphql_errors(errs)
        {:ok, _other} -> {:ok, %{notes: nil, action_items: [], bullet_gist: nil}}
        {:error, {:http_error, status, body}} -> handle_http_error(status, body)
        {:error, reason} -> {:error, reason}
      end
    end
  end

  # ============ Internals ============

  defp post_graphql(token, query, variables) do
    headers = [{"authorization", "Bearer #{token}"}, {"content-type", "application/json"}]

    Logger.debug(fn ->
      %{
        msg: "fireflies.graphql.request",
        query_preview: String.slice(String.replace(query, "\n", " "), 0, 120),
        variables: variables
      }
      |> Jason.encode!()
    end)

    case post("", %{query: query, variables: variables}, headers: headers) do
      {:ok, %Tesla.Env{status: 200, body: body}} ->
        Logger.debug(fn ->
          %{
            msg: "fireflies.graphql.response",
            status: 200,
            data: Map.get(body, "data"),
            errors: Map.get(body, "errors")
          }
          |> Jason.encode!()
        end)

        {:ok, body}

      {:ok, %Tesla.Env{status: status, body: body}} ->
        Logger.debug(fn ->
          %{
            msg: "fireflies.graphql.response",
            status: status,
            body: body
          }
          |> Jason.encode!()
        end)

        {:error, {:http_error, status, body}}

      {:error, reason} ->
        Logger.debug(fn ->
          %{
            msg: "fireflies.graphql.response",
            status: :error,
            reason: inspect(reason)
          }
          |> Jason.encode!()
        end)

        {:error, reason}
    end
  end

  defp token do
    conf = Application.get_env(:dashboard_ssd, :integrations, [])
    token = Keyword.get(conf, :fireflies_api_token) || System.get_env("FIREFLIES_API_TOKEN")

    if is_binary(token) and String.trim(token) != "" do
      {:ok, String.trim(token) |> strip_bearer()}
    else
      {:error, {:missing_env, "FIREFLIES_API_TOKEN"}}
    end
  end

  defp strip_bearer(token) do
    token
    |> String.replace_prefix("Bearer ", "")
    |> String.replace_prefix("bearer ", "")
  end

  defp drop_nils(map) when is_map(map) do
    map |> Enum.reject(fn {_k, v} -> is_nil(v) end) |> Map.new()
  end

  defp clamp(nil), do: nil
  defp clamp(limit) when is_integer(limit) and limit > 50, do: 50
  defp clamp(limit), do: limit

  defp sanitize_string_list(nil), do: nil

  defp sanitize_string_list(list) when is_list(list) do
    list
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> []
      xs -> xs
    end
  end

  @doc false
  @spec configured_user_id() :: String.t() | nil
  def configured_user_id do
    conf = Application.get_env(:dashboard_ssd, :integrations, [])

    user_id =
      case Keyword.get(conf, :fireflies_user_id) do
        v when is_binary(v) and v != "" -> v
        _ -> System.get_env("FIREFLIES_USER_ID")
      end

    user_id = if is_binary(user_id), do: String.trim(user_id), else: nil
    if user_id in [nil, ""], do: nil, else: user_id
  end

  # ===== Error helpers =====
  defp handle_graphql_errors(errs) when is_list(errs) do
    case find_rate_limit_error(errs) do
      {:rate_limited, msg} -> {:error, {:rate_limited, msg}}
      :none -> {:error, {:graphql_error, errs}}
    end
  end

  defp handle_http_error(429, body), do: {:error, {:rate_limited, extract_error_message(body) || "Too many requests"}}
  defp handle_http_error(status, body), do: {:error, {:http_error, status, body}}

  defp find_rate_limit_error(errs) do
    Enum.find_value(errs, :none, fn err ->
      code = Map.get(err, "code") || get_in(err, ["extensions", "code"]) || Map.get(err, :code)
      if is_binary(code) and String.downcase(code) == "too_many_requests" do
        {:rate_limited, Map.get(err, "message") || Map.get(err, :message) || "Too many requests"}
      else
        false
      end
    end)
  end

  defp extract_error_message(%{"errors" => [first | _]}) when is_map(first), do: Map.get(first, "message")
  defp extract_error_message(_), do: nil

  @doc """
  Lists users visible to the API token. Useful for discovering user_id for transcript queries.
  """
  @spec list_users() :: {:ok, [map()]} | {:error, term()}
  def list_users do
    with {:ok, token} <- token() do
      query = """
      query Users { users { user_id name integrations } }
      """

      case post_graphql(token, query, %{}) do
        {:ok, %{"data" => %{"users" => users}}} when is_list(users) -> {:ok, users}
        {:ok, %{"errors" => errs}} -> {:error, {:graphql_error, errs}}
        {:ok, _} -> {:ok, []}
        {:error, reason} -> {:error, reason}
      end
    end
  end
end
