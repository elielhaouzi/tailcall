defmodule Tailcall.Factory.Billing.Subscription do
  alias Tailcall.Billing.Subscriptions.{Subscription, SubscriptionItem}

  defmacro __using__(_opts) do
    quote do
      def build(:subscription, attrs) do
        {account_id, attrs} = Keyword.pop(attrs, :account_id)
        account_id = account_id || Map.get(insert!(:account), :id)

        {customer_id, attrs} = Keyword.pop(attrs, :customer_id)

        attrs =
          if customer_id do
            attrs |> Keyword.put(:customer_id, customer_id)
          else
            customer = insert!(:customer, account_id: account_id)

            attrs |> Keyword.put(:customer_id, customer.id) |> Keyword.put(:customer, customer)
          end

        utc_now = utc_now()

        %{
          price: %{
            recurring_interval: recurring_interval,
            recurring_interval_count: recurring_interval_count
          }
        } = subscription_item = build(:subscription_item, account_id: account_id)

        current_period_start = utc_now

        current_period_end =
          Timex.shift(current_period_start, [
            {String.to_atom("#{recurring_interval}s"), recurring_interval_count}
          ])

        %Subscription{
          account_id: account_id,
          customer_id: customer_id,
          created_at: utc_now,
          current_period_end: current_period_end,
          current_period_start: current_period_start,
          items: [subscription_item],
          livemode: false,
          started_at: utc_now,
          status: Subscription.statuses().active
        }
        |> struct!(attrs)
      end

      def make_ended(%Subscription{} = subscription), do: %{subscription | ended_at: utc_now()}

      def build(:subscription_item, attrs) do
        {account_id, attrs} = Keyword.pop(attrs, :account_id)
        {price_id, attrs} = Keyword.pop(attrs, :price_id)

        attrs =
          if price_id do
            attrs |> Keyword.put(:price_id, price_id)
          else
            price =
              build(:price, account_id: account_id)
              |> make_recurring_usage_type_licensed()
              |> make_billing_scheme_per_unit()
              |> insert!()

            attrs |> Keyword.put(:price_id, price.id) |> Keyword.put(:price, price)
          end

        utc_now = utc_now()

        %SubscriptionItem{
          account_id: account_id,
          created_at: utc_now,
          price_id: price_id,
          quantity: 1
        }
        |> struct!(attrs)
      end
    end
  end
end
