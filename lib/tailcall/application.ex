defmodule Tailcall.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      Tailcall.Repo,
      TailcallWeb.Telemetry,
      {Phoenix.PubSub, name: Tailcall.PubSub},
      TailcallWeb.Endpoint,
      {Oban, oban_config()}
      # Start a worker by calling: Tailcall.Worker.start_link(arg)
      # {Tailcall.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Tailcall.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    TailcallWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp oban_config do
    Application.get_env(:tailcall, Oban)
  end
end
