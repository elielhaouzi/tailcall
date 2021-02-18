defmodule Tailcall.Billing.Subscriptions.Workers.PastDueSubscriptionWorker do
  use Oban.Worker,
    queue: :subscriptions,
    unique: [
      period: :infinity,
      fields: [:queue, :args, :worker],
      keys: [:subscription_id, :invoice_id]
    ]

  alias Tailcall.Billing.Subscriptions
  alias Tailcall.Billing.Subscriptions.Subscription
  alias Tailcall.Billing.Invoices

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) :: :ok
  def perform(%Oban.Job{
        args: %{"subscription_id" => subscription_id, "invoice_id" => invoice_id} = _args
      }) do
    invoice_past_due? = invoice_id |> Invoices.get_invoice!() |> Invoices.past_due?()

    if invoice_past_due? do
      subscription_id
      |> Subscriptions.get_subscription!()
      |> Subscriptions.set_status!(Subscription.statuses().past_due)
    end

    :ok
  end
end
