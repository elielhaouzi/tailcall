import Config

config :tailcall,
  ecto_repos: [Tailcall.Repo]

config :tailcall, Tailcall.Repo,
  # ssl: true,
  show_sensitive_data_on_connection_error: false

config :annacl,
  repo: Tailcall.Repo,
  superadmin_role_name: "superadmin"

config :tailcall, TailcallWeb.Endpoint,
  http: [transport_options: [socket_opts: [:inet6]]],
  render_errors: [view: TailcallWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Tailcall.PubSub,
  live_view: [signing_salt: "dxfEY+EU"]

config :gettext, :default_locale, "en_US"

config :logger, :console,
  format: "$date $time $metadata[$level] $message\n",
  metadata: [:pid, :application, :mfa, :request_id]

config :phoenix, :json_library, Jason

import_config "#{Mix.env()}.exs"
