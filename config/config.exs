import Config

config :billing,
  ecto_repos: [Billing.Repo]

config :billing, Billing.Repo,
  # ssl: true,
  url: "#{System.get_env("BILLING__DATABASE_URL")}#{System.get_env("MIX_TEST_PARTITION")}",
  show_sensitive_data_on_connection_error: false,
  pool_size: System.get_env("BILLING__DATABASE_POOL_SIZE", "10") |> String.to_integer()

config :annacl,
  repo: Billing.Repo,
  superadmin_role_name: "superadmin"

# Configures the endpoint
config :billing, BillingWeb.Endpoint,
  url: [
    scheme: System.get_env("BILLING__ENDPOINT_URL_SCHEME", "http"),
    host: System.get_env("BILLING__ENDPOINT_URL_HOST", "localhost"),
    port: String.to_integer(System.get_env("BILLING__ENDPOINT_URL_PORT", "80"))
  ],
  http: [
    port: String.to_integer(System.get_env("BILLING__ENDPOINT_PORT") || "4000"),
    transport_options: [socket_opts: [:inet6]]
  ],
  secret_key_base: System.get_env("BILLING__ENDPOINT_SECRET_KEY_BASE"),
  render_errors: [view: BillingWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Billing.PubSub,
  live_view: [signing_salt: "dxfEY+EU"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$date $time $metadata[$level] $message\n",
  metadata: [:pid, :application, :mfa, :request_id]

config :logger,
  level: System.get_env("EX_LOG_LEVEL", "debug") |> String.to_atom()

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
