defmodule Tailcall.Factory.Billing.Price do
  alias Tailcall.Billing.Prices.Price
  alias Tailcall.Billing.Prices.PriceTier

  defmacro __using__(_opts) do
    quote do
      def build(:price) do
        account = insert!(:account)
        product = insert!(:product, account_id: account.id)

        %Price{
          account_id: account.id,
          product_id: product.id,
          created_at: utc_now(),
          currency: Price.currencies().ils,
          livemode: false,
          nickname: "nickname_#{System.unique_integer()}"
        }
        |> make_active()
        |> make_type_recurring()
      end

      def make_active(%Price{} = price), do: %{price | active: true}
      def make_inactive(%Price{} = price), do: %{price | active: false}
      def make_deleted(%Price{} = price), do: %{price | deleted_at: utc_now()}

      def make_type_one_time(%Price{} = price) do
        price
        |> Map.merge(%{
          type: Price.types().one_time,
          unit_amount: 1_000,
          recurring_interval: nil,
          recurring_interval_count: nil
        })
      end

      def make_type_recurring(%Price{} = price) do
        price
        |> Map.merge(%{
          type: Price.types().recurring,
          recurring_interval: Price.recurring_intervals().day,
          recurring_interval_count: 1
        })
      end

      def make_recurring_usage_type_licensed(%Price{} = price) do
        price
        |> Map.merge(%{
          recurring_usage_type: Price.recurring_usage_types().licensed
        })
      end

      def make_recurring_usage_type_metered(%Price{} = price) do
        price
        |> Map.merge(%{
          recurring_usage_type: Price.recurring_usage_types().metered
        })
        |> make_recurring_aggregate_usage_sum()
      end

      def make_recurring_usage_type_rated(%Price{} = price) do
        price
        |> Map.merge(%{
          recurring_usage_type: Price.recurring_usage_types().rated
        })
      end

      def make_recurring_aggregate_usage_sum(%Price{} = price) do
        price
        |> Map.merge(%{recurring_aggregate_usage: Price.recurring_aggregate_usages().sum})
      end

      def make_recurring_aggregate_usage_max(%Price{} = price) do
        price
        |> Map.merge(%{recurring_aggregate_usage: Price.recurring_aggregate_usages().max})
      end

      def make_billing_scheme_per_unit(%Price{} = price) do
        price
        |> Map.merge(%{billing_scheme: Price.billing_schemes().per_unit, unit_amount: 1_000})
      end

      def make_billing_scheme_tiered(%Price{} = price) do
        price
        |> Map.merge(%{billing_scheme: Price.billing_schemes().tiered})
        |> make_tiers_mode_volume()
      end

      def make_tiers_mode_volume(%Price{} = price) do
        price
        |> Map.merge(%{tiers_mode: Price.tiers_modes().volume})
        |> make_tiers()
      end

      def make_tiers_mode_graduated(%Price{} = price) do
        price
        |> Map.merge(%{tiers_mode: Price.tiers_modes().graduated})
        |> make_tiers()
      end

      def make_tiers(%Price{} = price) do
        price
        |> Map.merge(%{
          tiers: [
            params_for(:price_tier, unit_amount: 1_000, up_to: 5),
            params_for(:price_tier, unit_amount: 800, up_to: 10),
            params_for(:price_tier, unit_amount: 600, up_to: nil)
          ]
        })
      end

      def build(:price_tier) do
        %PriceTier{}
      end
    end
  end
end
