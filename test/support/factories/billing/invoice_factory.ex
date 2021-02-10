defmodule Tailcall.Factory.Billing.Invoice do
  alias Tailcall.Billing.Prices.Price
  alias Tailcall.Billing.Invoices.{Invoice, InvoiceLineItem}

  defmacro __using__(_opts) do
    quote do
      def build(:invoice) do
        account = insert!(:account)
        customer = insert!(:customer, account_id: account.id)
        subscription = insert!(:subscription, account_id: account.id)

        utc_now = utc_now()

        %Invoice{
          account_id: account.id,
          customer_id: customer.id,
          subscription_id: subscription.id,
          amount_due: 0,
          amount_paid: 0,
          amount_remaining: 0,
          billing_reason: Invoice.billing_reasons().subscription_cycle,
          created_at: utc_now,
          currency: Price.currencies().ils,
          livemode: false,
          period_end: utc_now,
          period_start: utc_now,
          status: Invoice.statuses().open,
          total: 0
        }
      end

      def make_deleted(%Invoice{} = invoice), do: %{invoice | deleted_at: utc_now()}

      def build(:invoice_line_item) do
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
      end
    end
  end
end
