defmodule Tailcall.Factory.Billing.Invoice do
  alias Tailcall.Billing.Prices.Price
  alias Tailcall.Billing.Subscriptions.Subscription
  alias Tailcall.Billing.Invoices.{Invoice, InvoiceLineItem}

  defmacro __using__(_opts) do
    quote do
      def build(:invoice, attrs) do
        {account_id, attrs} = Keyword.pop(attrs, :account_id)
        account_id = account_id || Map.get(insert!(:account), :id)

        {customer_id, attrs} = Keyword.pop(attrs, :customer_id)
        customer_id = customer_id || Map.get(insert!(:customer, account_id: account_id), :id)

        {subscription_id, attrs} = Keyword.pop(attrs, :subscription_id)

        subscription =
          if subscription_id do
            Subscription |> Tailcall.Repo.get(subscription_id)
          else
            insert!(:subscription, account_id: account_id, customer_id: customer_id)
          end

        invoice_line_items =
          subscription
          |> Tailcall.Repo.preload(:items)
          |> Map.get(:items)
          |> Enum.map(
            &build(:invoice_line_item,
              price_id: &1.price_id,
              subscription_id: subscription.id,
              subscription_item_id: &1.id,
              quantity: &1.quantity,
              type: InvoiceLineItem.types().subscription
            )
          )

        utc_now = utc_now()

        %Invoice{
          account_id: account_id,
          customer_id: customer_id,
          subscription_id: subscription.id,
          amount_due: 0,
          amount_paid: 0,
          amount_remaining: 0,
          billing_reason: Invoice.billing_reasons().subscription_cycle,
          created_at: utc_now,
          currency: Price.currencies().ils,
          line_items: invoice_line_items,
          livemode: false,
          number: "invoice_prefix-#{System.unique_integer([:positive])}",
          period_end: utc_now,
          period_start: utc_now,
          status: Invoice.statuses().open,
          total: 0
        }
        |> struct!(attrs)
      end

      def make_deleted(%Invoice{} = invoice), do: %{invoice | deleted_at: utc_now()}

      def build(:invoice_line_item, attrs) do
        utc_now = utc_now()

        %InvoiceLineItem{
          amount: 0,
          created_at: utc_now(),
          currency: Price.currencies().ils,
          livemode: false,
          period_end: utc_now,
          period_start: utc_now,
          type: InvoiceLineItem.types().subscription
        }
        |> struct!(attrs)
      end
    end
  end
end
