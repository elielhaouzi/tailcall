import Config

config :tailcall, Tailcall.Repo,
  url: "#{System.get_env("TAILCALL__DATABASE_URL")}#{System.get_env("MIX_TEST_PARTITION")}",
  pool_size: System.get_env("TAILCALL__DATABASE_POOL_SIZE", "10") |> String.to_integer()

config :tailcall, TailcallWeb.Endpoint,
  url: [
    scheme: System.get_env("TAILCALL__ENDPOINT_URL_SCHEME", "http"),
    host: System.get_env("TAILCALL__ENDPOINT_URL_HOST", "localhost"),
    port: String.to_integer(System.get_env("TAILCALL__ENDPOINT_URL_PORT", "80"))
  ],
  http: [
    port: String.to_integer(System.get_env("TAILCALL__ENDPOINT_PORT") || "4000")
  ],
  secret_key_base: System.get_env("TAILCALL__ENDPOINT_SECRET_KEY_BASE")

config :logger,
  level: System.get_env("EX_LOG_LEVEL", "debug") |> String.to_atom()
