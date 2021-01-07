defmodule Tailcall.Repo do
  use Ecto.Repo,
    otp_app: :tailcall,
    adapter: Ecto.Adapters.Postgres
end
