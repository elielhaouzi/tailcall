defmodule Tailcall.Billing.InvoincesTest do
  use ExUnit.Case, async: true
  use Tailcall.DataCase

  alias Tailcall.Billing.Prices.Price

  alias Tailcall.Billing.Invoices
  alias Tailcall.Billing.Invoices.Invoice

  @moduletag :invoices

  describe "list_invoices/1" do
    test "list invoices" do
      %{id: invoice_id} = insert!(:invoice)

      assert %{total: 1, data: [%{id: ^invoice_id}]} = Invoices.list_invoices()
    end

    test "order_by" do
      %{id: id1} = insert!(:invoice)
      %{id: id2} = insert!(:invoice)

      assert %{data: [%{id: ^id1}, %{id: ^id2}]} = Invoices.list_invoices()

      assert %{data: [%{id: ^id2}, %{id: ^id1}]} =
               Invoices.list_invoices(order_by_fields: [desc: :id])
    end

    test "filters" do
      invoice = insert!(:invoice)

      [
        [id: invoice.id],
        [id: [invoice.id]],
        [account_id: invoice.account_id],
        [customer_id: invoice.customer_id],
        [subscription_id: invoice.subscription_id],
        [livemode: invoice.livemode],
        [status: invoice.status]
      ]
      |> Enum.each(fn filter ->
        assert %{total: 1, data: [_price]} = Invoices.list_invoices(filters: filter)
      end)

      [
        [id: shortcode_id()],
        [account_id: shortcode_id()],
        [customer_id: shortcode_id()],
        [subscription_id: shortcode_id()],
        [livemode: !invoice.livemode],
        [status: "status"]
      ]
      |> Enum.each(fn filter ->
        assert %{total: 0, data: []} = Invoices.list_invoices(filters: filter)
      end)
    end

    test "includes" do
      account = insert!(:account)
      price = build(:price, account_id: account.id) |> insert!()
      customer = insert!(:customer, account_id: account.id)

      %{items: [subscription_item]} =
        subscription =
        insert!(:subscription,
          account_id: account.id,
          customer_id: customer.id,
          items: [build(:subscription_item, price_id: price.id, quantity: 1)]
        )

      insert!(:invoice,
        account_id: account.id,
        customer_id: customer.id,
        line_items: [
          build(:invoice_line_item,
            price_id: price.id,
            subscription_id: subscription.id,
            subscription_item_id: subscription_item.id
          )
        ]
      )

      %{data: [invoice], total: 1} = Invoices.list_invoices()

      assert Ecto.assoc_loaded?(invoice.line_items)
      assert Map.has_key?(invoice, :subscription_id)
      refute Ecto.assoc_loaded?(invoice.subscription)

      %{data: [invoice], total: 1} = Invoices.list_invoices(includes: [:subscription])

      assert Ecto.assoc_loaded?(invoice.subscription)
      assert Ecto.assoc_loaded?(invoice.subscription.items)
    end
  end

  describe "create_invoices/1" do
    test "when creating an invoice for a creation of a subscription, creates a invoice" do
      account = insert!(:account)
      product = insert!(:product, account_id: account.id)

      price =
        build(:price, account_id: account.id, product_id: product.id)
        |> make_type_recurring(%{
          recurring_interval: Price.recurring_intervals().day,
          recurring_interval_count: 1
        })
        |> make_recurring_usage_type_licensed()
        |> make_billing_scheme_per_unit()
        |> insert!()

      customer = insert!(:customer, account_id: account.id)

      %{items: [subscription_item]} =
        subscription =
        insert!(:subscription,
          account_id: account.id,
          customer_id: customer.id,
          items: [build(:subscription_item, price_id: price.id, quantity: 2)]
        )

      assert {:ok, %Invoice{line_items: [invoice_line_item]} = invoice} =
               Invoices.create_invoice(%{
                 account_id: subscription.account_id,
                 customer_id: subscription.customer_id,
                 subscription_id: subscription.id,
                 account_name: account.name,
                 billing_reason: Invoice.billing_reasons().subscription_create,
                 currency: price.currency,
                 customer_email: customer.email,
                 customer_name: customer.name,
                 line_items: [
                   %{
                     amount: price.unit_amount * subscription_item.quantity,
                     period_end: subscription.current_period_end,
                     period_start: subscription.current_period_start,
                     price_id: subscription_item.price_id,
                     quantity: subscription_item.quantity,
                     subscription_item_id: subscription_item.id,
                     type: Invoices.InvoiceLineItem.types().subscription
                   }
                 ],
                 livemode: subscription.livemode,
                 period_end: subscription.current_period_start,
                 period_start: subscription.current_period_start,
                 total: price.unit_amount * subscription_item.quantity
               })

      assert invoice.account_id == subscription.account_id
      assert invoice.account_name == account.name
      assert invoice.amount_due == price.unit_amount * subscription_item.quantity
      assert invoice.amount_paid == 0
      assert invoice.amount_remaining == invoice.amount_due - invoice.amount_paid
      assert invoice.billing_reason == Invoice.billing_reasons().subscription_create

      assert invoice.customer_id == customer.id
      assert invoice.customer_email == customer.email
      assert invoice.customer_name == customer.name

      assert invoice.subscription_id == subscription.id
      assert invoice.currency == price.currency
      assert invoice.period_end == subscription.current_period_start
      assert invoice.period_start == subscription.current_period_start
      assert invoice.status == Invoice.statuses().draft
      assert invoice.total == price.unit_amount * subscription_item.quantity

      assert invoice_line_item.amount == price.unit_amount * subscription_item.quantity
      assert invoice_line_item.currency == price.currency
      assert invoice_line_item.period_end == subscription.current_period_start
      assert invoice_line_item.period_start == subscription.current_period_start
      assert invoice_line_item.quantity == subscription_item.quantity
      assert invoice_line_item.type == Invoices.InvoiceLineItem.types().subscription

      assert_enqueued(
        worker: Tailcall.Billing.Invoices.Workers.AutoAdvanceWorker,
        args: %{id: invoice.id},
        scheduled_at: DateTime.add(invoice.created_at, 3600, :second)
      )
    end
  end
end
