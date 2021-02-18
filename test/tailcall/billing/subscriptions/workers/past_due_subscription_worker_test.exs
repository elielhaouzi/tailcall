defmodule Tailcall.Billing.Subscriptions.Workers.PastDueSubscriptionWorkerTest do
  use ExUnit.Case, async: true
  use Tailcall.DataCase

  alias Tailcall.Billing.Subscriptions
  alias Tailcall.Billing.Subscriptions.Subscription
  alias Tailcall.Billing.Invoices.Invoice

  alias Tailcall.Billing.Subscriptions.Workers.PastDueSubscriptionWorker

  @moduletag :subscriptions

  test "when the invoice is not past_due, does not update the subscription" do
    %{status: status} =
      subscription = insert!(:subscription, status: Subscription.statuses().active)

    invoice =
      insert!(:invoice,
        subscription_id: subscription.id,
        status: Invoice.statuses().paid,
        due_date: utc_now() |> add(3600)
      )

    assert :ok =
             perform_job(PastDueSubscriptionWorker, %{
               subscription_id: subscription.id,
               invoice_id: invoice.id
             })

    assert %{status: ^status} = Subscriptions.get_subscription!(subscription.id)
  end

  test "when the invoice is past_due, updates the subscription" do
    subscription = insert!(:subscription, status: Subscription.statuses().active)

    invoice =
      insert!(:invoice,
        subscription_id: subscription.id,
        status: Invoice.statuses().paid,
        due_date: utc_now() |> add(-3600)
      )

    assert :ok =
             perform_job(PastDueSubscriptionWorker, %{
               subscription_id: subscription.id,
               invoice_id: invoice.id
             })

    subscription = Subscriptions.get_subscription!(subscription.id)
    assert subscription.status == Subscription.statuses().past_due
  end
end
