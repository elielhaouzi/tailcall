defmodule Tailcall.Billing.Subscriptions.Workers.RenewSubscriptionWorker do
  use Oban.Worker,
    queue: :subscriptions,
    unique: [period: :infinity, fields: [:queue, :args, :worker], keys: [:id]]

  alias Tailcall.Billing.Subscriptions
  @impl Oban.Worker
  @spec perform(Oban.Job.t()) ::
          {:ok, Subscriptions.Subscription.t()} | {:error, Ecto.Changeset.t()}
  def perform(%Oban.Job{args: %{"id" => id} = _args}) do
    id |> Subscriptions.get_subscription!() |> Subscriptions.renew_subscription()
  end
end
