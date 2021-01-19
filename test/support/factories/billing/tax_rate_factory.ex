defmodule Tailcall.Factory.Billing.TaxRate do
  alias Tailcall.Billing.TaxRates.TaxRate

  defmacro __using__(_opts) do
    quote do
      def build(:tax_rate) do
        user = insert!(:user)

        %TaxRate{
          user_id: user.id,
          created_at: utc_now(),
          description: "description_#{System.unique_integer()}",
          display_name: "display_name_#{System.unique_integer()}",
          jurisdiction: "jurisdiction_#{System.unique_integer()}",
          livemode: false,
          metadata: %{key: "value"},
          percentage: 17.0
        }
        |> make_active()
        |> make_inclusive()
      end

      def make_active(%TaxRate{} = tax_rate) do
        tax_rate
        |> Map.merge(%{active: true})
      end

      def make_inactive(%TaxRate{} = tax_rate) do
        tax_rate
        |> Map.merge(%{active: false})
      end

      def make_inclusive(%TaxRate{} = tax_rate) do
        tax_rate
        |> Map.merge(%{inclusive: true})
      end

      def make_exclusive(%TaxRate{} = tax_rate) do
        tax_rate
        |> Map.merge(%{inclusive: false})
      end

      def make_deleted(%TaxRate{} = tax_rate) do
        tax_rate
        |> Map.merge(%{deleted_at: utc_now()})
      end
    end
  end
end
