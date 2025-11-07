import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/dashboard_ssd start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :dashboard_ssd, DashboardSSDWeb.Endpoint, server: true
end

# Load environment variables from a local .env file in development before reading config.
# This ensures Application config picks up values from .env without requiring export.
if config_env() in [:dev, :test] do
  env_path = Path.expand("../.env", __DIR__)

  if File.exists?(env_path) do
    env_lines = File.stream!(env_path, [], :line)

    Enum.each(env_lines, fn line ->
      line = String.trim(line)

      cond do
        line == "" ->
          :ok

        String.starts_with?(line, "#") ->
          :ok

        true ->
          [key | rest] = String.split(line, "=", parts: 2)
          key = key |> String.trim_leading("export ") |> String.trim()
          value = rest |> List.first() |> to_string() |> String.trim()

          value =
            cond do
              String.starts_with?(value, "\"") and String.ends_with?(value, "\"") ->
                value |> String.trim_leading("\"") |> String.trim_trailing("\"")

              String.starts_with?(value, "'") and String.ends_with?(value, "'") ->
                value |> String.trim_leading("'") |> String.trim_trailing("'")

              true ->
                Regex.replace(~r/\s+#.*$/, value, "")
            end

          if key != "" and System.get_env(key) in [nil, ""] do
            System.put_env(key, value)
          end
      end
    end)
  end
end

# Integration tokens (optional; for local/dev usage)
# Values read from environment; safe to be nil in non-dev envs.
notion_token = System.get_env("NOTION_TOKEN") || System.get_env("NOTION_API_KEY")

raw_curated_database_ids =
  System.get_env("NOTION_CURATED_DATABASE_IDS") ||
    System.get_env("NOTION_DATABASE_ALLOWLIST") ||
    System.get_env("NOTION_COLLECTION_ALLOWLIST")

knowledge_base_config =
  Application.get_env(:dashboard_ssd, DashboardSSD.KnowledgeBase, [])

curated_collections_path = Keyword.get(knowledge_base_config, :curated_collections_path)

parse_env_list = fn
  nil, default ->
    default

  value, _default ->
    value
    |> String.split([",", "\n"], trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
end

parse_env_boolean = fn
  nil, default ->
    default

  value, default_value ->
    value
    |> String.trim()
    |> String.downcase()
    |> case do
      v when v in ["1", "true", "yes", "on"] -> true
      v when v in ["0", "false", "no", "off"] -> false
      _ -> default_value
    end
end

parse_discovery_mode = fn
  nil, default ->
    default

  value, default ->
    value
    |> String.trim()
    |> String.downcase()
    |> case do
      mode when mode in ["pages", "page"] -> :pages
      mode when mode in ["databases", "database", "db", "databse"] -> :databases
      _ -> default
    end
end

# hide empty collections if
# raw_curated_database_ids is not set and env is not :test
hide_empty_collections =
  if !raw_curated_database_ids && config_env() != :test do
    true
  else
    false
  end

allowed_document_type_values =
  parse_env_list.(
    System.get_env("NOTION_ALLOWED_PAGE_TYPES"),
    Keyword.get(knowledge_base_config, :allowed_document_type_values, ["Wiki"])
  )

document_type_property_names =
  parse_env_list.(
    System.get_env("NOTION_PAGE_TYPE_PROPERTIES"),
    Keyword.get(knowledge_base_config, :document_type_property_names, ["Type"])
  )

allow_documents_without_type? =
  parse_env_boolean.(
    System.get_env("NOTION_ALLOW_UNTYPED_DOCUMENTS"),
    Keyword.get(knowledge_base_config, :allow_documents_without_type?, true)
  )

document_type_filter_exempt_ids =
  parse_env_list.(
    System.get_env("NOTION_PAGE_TYPE_FILTER_EXEMPT_IDS"),
    Keyword.get(knowledge_base_config, :document_type_filter_exempt_ids, [])
  )

auto_discover? =
  parse_env_boolean.(
    System.get_env("NOTION_AUTO_DISCOVER"),
    Keyword.get(knowledge_base_config, :auto_discover?, true)
  )

auto_discover_mode =
  parse_discovery_mode.(
    System.get_env("NOTION_KB_DISCOVERY_MODE"),
    Keyword.get(knowledge_base_config, :auto_discover_mode, :databases)
  )

auto_page_collection_id =
  System.get_env("NOTION_PAGE_COLLECTION_ID") ||
    Keyword.get(knowledge_base_config, :auto_page_collection_id, "kb:auto:pages")

auto_page_collection_name =
  System.get_env("NOTION_PAGE_COLLECTION_NAME") ||
    Keyword.get(knowledge_base_config, :auto_page_collection_name, "Wiki Pages")

auto_page_collection_description =
  System.get_env("NOTION_PAGE_COLLECTION_DESCRIPTION") ||
    Keyword.get(
      knowledge_base_config,
      :auto_page_collection_description,
      "Top-level pages from the company wiki"
    )

{curated_collections_sample, fallback_curated_database_ids} =
  if config_env() == :prod do
    {[], []}
  else
    cond do
      is_nil(curated_collections_path) ->
        {[], []}

      not Code.ensure_loaded?(Jason) ->
        {[], []}

      not File.exists?(curated_collections_path) ->
        {[], []}

      true ->
        with {:ok, body} <- File.read(curated_collections_path),
             {:ok, %{"collections" => collections}} when is_list(collections) <-
               Jason.decode(body) do
          normalized =
            collections
            |> Enum.map(fn collection ->
              %{
                "id" => Map.get(collection, "id"),
                "name" => Map.get(collection, "name"),
                "description" => Map.get(collection, "description"),
                "icon" => Map.get(collection, "icon")
              }
            end)
            |> Enum.reject(fn collection -> collection["id"] in [nil, ""] end)

          ids =
            normalized
            |> Enum.map(& &1["id"])
            |> Enum.filter(&(&1 && &1 != ""))
            |> Enum.uniq()

          {normalized, ids}
        else
          _ -> {[], []}
        end
    end
  end

knowledge_base_config =
  knowledge_base_config
  |> Keyword.put(:hide_empty_collections, hide_empty_collections)
  |> Keyword.put(:curated_collections, curated_collections_sample)
  |> Keyword.put(:default_curated_database_ids, fallback_curated_database_ids)
  |> Keyword.put(:allowed_document_type_values, allowed_document_type_values)
  |> Keyword.put(:document_type_property_names, document_type_property_names)
  |> Keyword.put(:document_type_filter_exempt_ids, document_type_filter_exempt_ids)
  |> Keyword.put(:allow_documents_without_type?, allow_documents_without_type?)
  |> Keyword.put(:auto_discover?, auto_discover?)
  |> Keyword.put(:auto_discover_mode, auto_discover_mode)
  |> Keyword.put(:auto_page_collection_id, auto_page_collection_id)
  |> Keyword.put(:auto_page_collection_name, auto_page_collection_name)
  |> Keyword.put(:auto_page_collection_description, auto_page_collection_description)

Application.put_env(:dashboard_ssd, DashboardSSD.KnowledgeBase, knowledge_base_config)

parsed_curated_database_ids =
  case raw_curated_database_ids do
    nil ->
      []

    value ->
      value
      |> String.split([",", "\n"], trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()
  end

notion_curated_database_ids =
  case parsed_curated_database_ids do
    [] -> fallback_curated_database_ids
    ids -> ids
  end

if config_env() == :prod do
  if is_nil(notion_token) or notion_token == "" do
    raise """
    environment variable NOTION_TOKEN (or NOTION_API_KEY) is missing.
    """
  end

  if notion_curated_database_ids == [] do
    raise """
    environment variable NOTION_CURATED_DATABASE_IDS is missing. Provide a comma-separated list of Notion database IDs.
    """
  end
end

config :dashboard_ssd, :integrations,
  # Accept both *_TOKEN and *_API_KEY naming
  linear_token: System.get_env("LINEAR_TOKEN") || System.get_env("LINEAR_API_KEY"),
  slack_bot_token: System.get_env("SLACK_BOT_TOKEN") || System.get_env("SLACK_API_KEY"),
  slack_channel: System.get_env("SLACK_CHANNEL"),
  notion_token: notion_token,
  notion_curated_database_ids: notion_curated_database_ids,
  # For Drive, prefer a direct access token if present; otherwise rely on user-scoped DB token
  drive_token:
    System.get_env("GOOGLE_DRIVE_TOKEN") ||
      System.get_env("GOOGLE_OAUTH_TOKEN"),
  # Fireflies API token for Meetings integration
  fireflies_api_token: System.get_env("FIREFLIES_API_TOKEN")

# Load environment variables from a local .env file in development.
# This helps when running locally without exporting vars manually.

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  # The CA certificate is provided as a PEM-encoded string.
  # Need to convert it to DER.
  cacert = System.get_env("CA_CERT")
  pem_entries = :public_key.pem_decode(cacert)
  cacerts = for {:Certificate, cert, :not_encrypted} <- pem_entries, do: cert

  config :dashboard_ssd, DashboardSSD.Repo,
    # enable ssl for connection in production (eg: AWS RDS)
    ssl: [
      verify: :verify_peer,
      versions: [:"tlsv1.3"],
      ciphers: :ssl.cipher_suites(:all, :"tlsv1.3"),
      cacerts: cacerts
    ],
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :dashboard_ssd, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :dashboard_ssd, DashboardSSDWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :dashboard_ssd, DashboardSSDWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :dashboard_ssd, DashboardSSDWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Also, you may need to configure the Swoosh API client of your choice if you
  # are not using SMTP. Here is an example of the configuration:
  #
  #     config :dashboard_ssd, DashboardSSD.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # For this example you need include a HTTP client required by Swoosh API client.
  # Swoosh supports Hackney and Finch out of the box:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Hackney
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end

if config_env() in [:dev, :prod] do
  config :ueberauth, Ueberauth.Strategy.Google.OAuth,
    client_id: System.get_env("GOOGLE_CLIENT_ID"),
    client_secret: System.get_env("GOOGLE_CLIENT_SECRET")
end

# Configure Cloak vault for encrypting sensitive fields
if config_env() == :test do
  # Use a deterministic fallback key in tests if not provided
  key_b64 = System.get_env("ENCRYPTION_KEY") || Base.encode64(String.duplicate("0", 32))

  key =
    case Base.decode64(key_b64) do
      {:ok, key} -> key
      :error -> raise "ENCRYPTION_KEY must be base64-encoded"
    end

  config :dashboard_ssd, DashboardSSD.Vault,
    ciphers: [
      default: {Cloak.Ciphers.AES.GCM, tag: "AES.GCM.V1", key: key, iv_length: 12}
    ]
end

if config_env() in [:dev, :prod] do
  key_b64 =
    System.get_env("ENCRYPTION_KEY") ||
      raise "ENCRYPTION_KEY is missing. Generate with: openssl rand -base64 32 and put in .env"

  key =
    case Base.decode64(key_b64) do
      {:ok, key} -> key
      :error -> raise "ENCRYPTION_KEY must be base64-encoded"
    end

  config :dashboard_ssd, DashboardSSD.Vault,
    ciphers: [
      default: {Cloak.Ciphers.AES.GCM, tag: "AES.GCM.V1", key: key, iv_length: 12}
    ]
end
