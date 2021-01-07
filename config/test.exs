import Config

config :billing, Billing.Repo,
  show_sensitive_data_on_connection_error: true,
  pool: Ecto.Adapters.SQL.Sandbox

config :plug, :validate_header_keys_during_test, false
