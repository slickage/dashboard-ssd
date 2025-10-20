defmodule DashboardSSD.KnowledgeBase.Instrumentation do
  @moduledoc """
  Telemetry helpers and structured logging for Knowledge Base integrations.

  Currently focuses on Notion API interactions, emitting span events under
  `[:dashboard_ssd, :knowledge_base, :notion, :request]`.
  """
  require Logger

  @event_prefix [:dashboard_ssd, :knowledge_base, :notion, :request]
  @stop_event @event_prefix ++ [:stop]

  @doc """
  Returns the telemetry event name for stop events.
  """
  @spec event() :: [:dashboard_ssd | :knowledge_base | :notion | :request | :stop, ...]
  def event, do: @stop_event

  @doc """
  Executes `fun` within a telemetry span, annotating the call with the provided metadata.

  The function should return either:

    * `{:ok, %Tesla.Env{}}`
    * `{:error, {:http_error, status, body}}`
    * `{:error, reason}`

  Any other return value is treated as a successful result.
  """
  @spec with_request_span(atom(), map(), (-> term())) :: term()
  def with_request_span(operation, metadata \\ %{}, fun) when is_function(fun, 0) do
    base_metadata =
      metadata
      |> Map.new()
      |> Map.put(:operation, operation)

    :telemetry.span(@event_prefix, base_metadata, fn ->
      case fun.() do
        {:ok, %Tesla.Env{status: status}} = result ->
          stop_metadata = Map.merge(base_metadata, %{status: :ok, http_status: status})
          {result, stop_metadata}

        {:error, {:http_error, status, body}} = result ->
          stop_metadata =
            base_metadata
            |> Map.put(:status, :error)
            |> Map.put(:http_status, status)
            |> Map.put(:error, body)

          {result, stop_metadata}

        {:error, reason} = result ->
          stop_metadata =
            base_metadata
            |> Map.put(:status, :error)
            |> Map.put(:error, reason)

          {result, stop_metadata}

        result ->
          {result, Map.put(base_metadata, :status, :ok)}
      end
    end)
  end

  @doc """
  Attaches structured logging for Notion request telemetry events.
  """
  @spec attach_logger(term()) :: :ok | {:error, :already_exists}
  def attach_logger(id \\ __MODULE__) do
    :telemetry.attach(id, @stop_event, &__MODULE__.handle_event/4, %{})
  end

  @doc "Detaches the structured logging handler."
  @spec detach_logger(term()) :: :ok
  def detach_logger(id \\ __MODULE__) do
    case :telemetry.detach(id) do
      :ok -> :ok
      {:error, :not_found} -> :ok
    end
  end

  @doc false
  @spec handle_event(term(), map(), map(), term()) :: :ok
  def handle_event(_event, measurements, metadata, _config) do
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)

    level =
      case metadata[:status] do
        :ok -> :info
        :error -> :warning
        _ -> :info
      end

    Logger.log(level, fn ->
      message =
        case metadata[:status] do
          :ok -> "Notion request succeeded"
          :error -> "Notion request failed"
          other -> "Notion request #{inspect(other)}"
        end

      log_metadata =
        metadata
        |> Map.take([:operation, :method, :path, :attempt, :http_status, :error])
        |> Map.put(:duration_ms, duration_ms)

      {message, log_metadata}
    end)
  end
end
