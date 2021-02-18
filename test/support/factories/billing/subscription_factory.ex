defmodule Tailcall.Factory.Billing.Subscription do
  alias Tailcall.Billing.Subscriptions.{Subscription, SubscriptionItem}

  defmacro __using__(_opts) do
    quote do
      def build(:subscription, attrs) do
        {account_id, attrs} = Keyword.pop(attrs, :account_id)
        account_id = account_id || Map.get(insert!(:account), :id)

        {customer_id, attrs} = Keyword.pop(attrs, :customer_id)
        customer_id = customer_id || Map.get(insert!(:customer, account_id: account_id), :id)

        utc_now = utc_now()

        %Subscription{
          account_id: account_id,
          customer_id: customer_id,
          created_at: utc_now,
          current_period_end: utc_now,
          current_period_start: utc_now,
          items: [build(:subscription_item, account_id: account_id)],
          livemode: false,
          started_at: utc_now,
          status: Subscription.statuses().active
        }
        |> struct!(attrs)
      end

      def make_ended(%Subscription{} = subscription), do: %{subscription | ended_at: utc_now()}

      def build(:subscription_item, attrs) do
        {account_id, attrs} = Keyword.pop(attrs, :account_id)

        price =
          build(:price, account_id: account_id)
          |> make_recurring_usage_type_licensed()
          |> make_billing_scheme_per_unit()
          |> insert!()

        utc_now = utc_now()

        %SubscriptionItem{
          created_at: utc_now,
          price_id: price.id,
          quantity: 1,
          started_at: utc_now
        }
        |> struct!(attrs)
      end
    end
  end
end
