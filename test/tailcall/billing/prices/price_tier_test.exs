defmodule Tailcall.Billing.Prices.PriceTierTest do
  use ExUnit.Case, async: true
  use Tailcall.DataCase

  alias Tailcall.Billing.Prices.PriceTier

  describe "changeset/2" do
    test "only permitted_keys are casted" do
      price_tier_params =
        params_for(:price_tier,
          flat_amount: 1,
          flat_amount_decimal: 10,
          unit_amount: 1,
          unit_amount_decimal: 10,
          up_to: 5
        )

      changeset =
        PriceTier.changeset(%PriceTier{}, Map.merge(price_tier_params, %{new_key: "value"}))

      changes_keys = changeset.changes |> Map.keys()

      assert :flat_amount in changes_keys
      assert :flat_amount_decimal in changes_keys
      assert :unit_amount in changes_keys
      assert :unit_amount_decimal in changes_keys
      assert :up_to in changes_keys
      refute :new_key in changes_keys
    end

    test "when required params are missing, returns an invalid changeset" do
      price_tier_params =
        params_for(:price_tier,
          flat_amount: nil,
          flat_amount_decimal: nil,
          unit_amount: nil,
          unit_amount_decimal: nil,
          up_to: nil
        )

      changeset = PriceTier.changeset(%PriceTier{}, price_tier_params)

      refute changeset.valid?

      assert %{
               tier: [
                 "at least 1 of [:unit_amount, :unit_amount_decimal, :flat_amount, :flat_amount_decimal] can't be blank"
               ]
             } = errors_on(changeset)
    end

    test "when data is not valid, returns an invalid changeset" do
      price_tier_params =
        params_for(:price_tier,
          flat_amount: "flat_amount",
          flat_amount_decimal: "flat_amount_decimal",
          unit_amount: "unit_amount",
          unit_amount_decimal: "unit_amount_decimal",
          up_to: "up_to"
        )

      changeset = PriceTier.changeset(%PriceTier{}, price_tier_params)

      refute changeset.valid?
      assert %{flat_amount: ["is invalid"]} = errors_on(changeset)
      assert %{flat_amount_decimal: ["is invalid"]} = errors_on(changeset)
      assert %{unit_amount: ["is invalid"]} = errors_on(changeset)
      assert %{unit_amount_decimal: ["is invalid"]} = errors_on(changeset)
      assert %{up_to: ["is invalid"]} = errors_on(changeset)
    end

    test "when unit_amount and unit_amount_decimal are set, returns an invalid changeset" do
      changeset =
        PriceTier.changeset(
          %PriceTier{},
          params_for(:price_tier, unit_amount: 5, unit_amount_decimal: 1000)
        )

      refute changeset.valid?

      assert %{
               tier: [
                 "only one of [:unit_amount, :unit_amount_decimal] must be present"
               ]
             } = errors_on(changeset)
    end

    test "when flat_amount and flat_amount_decimal are set, returns an invalid changeset" do
      changeset =
        PriceTier.changeset(
          %PriceTier{},
          params_for(:price_tier, flat_amount: 5, flat_amount_decimal: 1000)
        )

      refute changeset.valid?

      assert %{
               tier: [
                 "only one of [:flat_amount, :flat_amount_decimal] must be present"
               ]
             } = errors_on(changeset)
    end

    test "when all params are valid, returns an valid changeset" do
      price_tier_params = params_for(:price_tier, unit_amount: 1000)

      changeset = PriceTier.changeset(%PriceTier{}, price_tier_params)

      assert changeset.valid?
    end

    test "when unit_amount is set, set unit_amount_decimal to the same value as decimal" do
      price_tier_params = params_for(:price_tier, unit_amount: 5000)

      changeset = PriceTier.changeset(%PriceTier{}, price_tier_params)

      assert changeset.valid?

      unit_amount = get_field(changeset, :unit_amount)
      unit_amount_decimal = get_field(changeset, :unit_amount_decimal)

      assert unit_amount_decimal == Decimal.new(unit_amount)
    end

    test "when flat_amount is set, set flat_amount_decimal to the same value as decimal" do
      price_tier_params = params_for(:price_tier, flat_amount: 5000)

      changeset = PriceTier.changeset(%PriceTier{}, price_tier_params)

      assert changeset.valid?

      flat_amount = get_field(changeset, :flat_amount)
      flat_amount_decimal = get_field(changeset, :flat_amount_decimal)

      assert flat_amount_decimal == Decimal.new(flat_amount)
    end
  end
end
