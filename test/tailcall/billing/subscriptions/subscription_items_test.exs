defmodule Tailcall.Billing.Subscriptions.SubscriptionItemsTest do
  use ExUnit.Case, async: true
  use Tailcall.DataCase

  alias Tailcall.Billing.InvoiceItems

  alias Tailcall.Billing.Subscriptions
  alias Tailcall.Billing.Subscriptions.Subscription
  alias Tailcall.Billing.Subscriptions.SubscriptionItems
  alias Tailcall.Billing.Subscriptions.SubscriptionItems.SubscriptionItem

  @moduletag :subscriptions

  describe "create_subscription_item/3" do
    test "adding an prepaid item with proration with a licensed per_unit price, 1.creates the subscription_item 2.creates the invoice_items 3.returns the subscription_item" do
      account = insert!(:account)

      price_1 =
        build(:price, account_id: account.id)
        |> make_type_recurring()
        |> make_recurring_interval_per_day()
        |> make_recurring_usage_type_licensed()
        |> make_billing_scheme_per_unit()
        |> insert!()

      price_2 =
        build(:price, account_id: account.id)
        |> make_type_recurring()
        |> make_recurring_interval_per_day()
        |> make_recurring_usage_type_licensed()
        |> make_billing_scheme_per_unit()
        |> insert!()

      subscription_factory =
        insert!(:subscription,
          account_id: account.id,
          items: [build(:subscription_item, account_id: account.id, price_id: price_1.id)]
        )

      proration_date = utc_now() |> add(8 * 3600)

      assert {:ok, %SubscriptionItem{} = subscription_item} =
               SubscriptionItems.create_subscription_item(subscription_factory, %{
                 price_id: price_2.id,
                 proration_behavior: Subscription.proration_behaviors().create_proration,
                 proration_date: proration_date
               })

      %Subscription{items: [_, _]} =
        subscription = Subscriptions.get_subscription!(subscription_factory.id)

      assert subscription.current_period_start == subscription_factory.current_period_start
      assert subscription.current_period_end == subscription_factory.current_period_end

      assert subscription_item.subscription_id == subscription.id
      assert subscription_item.price_id == price_2.id
      assert subscription_item.quantity == 1
      assert subscription_item.subscription_id == subscription.id

      billing_period_in_seconds =
        DateTime.diff(subscription.current_period_end, subscription.current_period_start)

      debit_remaining_time =
        subscription.current_period_end
        |> DateTime.diff(proration_date)
        |> Kernel.*(100)
        |> Decimal.div(billing_period_in_seconds)
        |> Decimal.mult(subscription_item.price.unit_amount * subscription_item.quantity)
        |> Decimal.div(100)
        |> Decimal.round()
        |> Decimal.to_integer()

      assert %{data: [debit_invoice_item]} =
               InvoiceItems.list_invoice_items(filter: [subscription_id: subscription.id])

      assert debit_invoice_item.amount == debit_remaining_time
      assert debit_invoice_item.is_proration
      assert debit_invoice_item.subscription_item_id == subscription_item.id
      assert debit_invoice_item.period_start == proration_date
      assert debit_invoice_item.period_end == subscription.current_period_end
    end

    test "proration_date is out of the current_period range, returns an invalid changeset" do
      account = insert!(:account)

      price_1 =
        build(:price, account_id: account.id)
        |> make_type_recurring()
        |> make_recurring_interval_per_day()
        |> make_recurring_usage_type_licensed()
        |> make_billing_scheme_per_unit()
        |> insert!()

      price_2 =
        build(:price, account_id: account.id)
        |> make_type_recurring()
        |> make_recurring_interval_per_day()
        |> make_recurring_usage_type_licensed()
        |> make_billing_scheme_per_unit()
        |> insert!()

      subscription_factory =
        insert!(:subscription,
          account_id: account.id,
          items: [build(:subscription_item, account_id: account.id, price_id: price_1.id)]
        )

      proration_date = subscription_factory.current_period_start |> add(-8 * 3600)

      assert {:error, %Ecto.Changeset{} = changeset} =
               SubscriptionItems.create_subscription_item(subscription_factory, %{
                 price_id: price_2.id,
                 proration_behavior: Subscription.proration_behaviors().create_proration,
                 proration_date: proration_date
               })

      refute changeset.valid?

      assert %{
               proration_date: [
                 "should be after or equal to #{subscription_factory.current_period_start}"
               ]
             } == errors_on(changeset)

      proration_date = subscription_factory.current_period_end |> add(8 * 3600)

      assert {:error, %Ecto.Changeset{} = changeset} =
               SubscriptionItems.create_subscription_item(subscription_factory, %{
                 price_id: price_2.id,
                 proration_behavior: Subscription.proration_behaviors().create_proration,
                 proration_date: proration_date
               })

      refute changeset.valid?

      assert %{
               proration_date: [
                 "should be before or equal to #{subscription_factory.current_period_end}"
               ]
             } == errors_on(changeset)
    end
  end
end
