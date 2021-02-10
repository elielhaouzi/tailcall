defmodule Tailcall.Factory.Billing.Subscription do
  alias Tailcall.Billing.Subscriptions.{Subscription, SubscriptionItem}

  defmacro __using__(_opts) do
    quote do
      def build(:subscription) do
        account = insert!(:account)
        customer = insert!(:customer)

        utc_now = utc_now()

        %Subscription{
          account_id: account.id,
          customer_id: customer.id,
          created_at: utc_now,
          current_period_end: utc_now,
          current_period_start: utc_now,
          items: [],
          livemode: false,
          started_at: utc_now,
          status: Subscription.statuses().active
        }
      end

      def make_ended(%Subscription{} = subscription), do: %{subscription | ended_at: utc_now()}

      def build(:subscription_item) do
        price = insert!(:price)

        utc_now = utc_now()

        %SubscriptionItem{
          created_at: utc_now,
          price_id: price.id,
          started_at: utc_now
        }
      end
    end
  end
end
