import Config

config :billing,
  ecto_repos: [Billing.Repo]

config :billing, Billing.Repo,
  # ssl: true,
  show_sensitive_data_on_connection_error: false

config :annacl,
  repo: Billing.Repo,
  superadmin_role_name: "superadmin"

config :billing, BillingWeb.Endpoint,
  http: [transport_options: [socket_opts: [:inet6]]],
  render_errors: [view: BillingWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Billing.PubSub,
  live_view: [signing_salt: "dxfEY+EU"]

config :gettext, :default_locale, "en_US"

config :logger, :console,
  format: "$date $time $metadata[$level] $message\n",
  metadata: [:pid, :application, :mfa, :request_id]

config :phoenix, :json_library, Jason

import_config "#{Mix.env()}.exs"
