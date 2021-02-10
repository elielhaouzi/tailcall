import Config

config :tailcall, Tailcall.Repo,
  show_sensitive_data_on_connection_error: true,
  pool: Ecto.Adapters.SQL.Sandbox

config :tailcall, Oban, queues: false, plugins: false

config :plug, :validate_header_keys_during_test, false
