defmodule Tailcall.Billing.Prices.PriceTest do
  use ExUnit.Case, async: true
  use Tailcall.DataCase

  alias Tailcall.Billing.Prices.Price
  alias Tailcall.Billing.Prices.PriceTier

  describe "create_changeset/2 - type: common for all" do
    test "only permitted_keys are casted" do
      price_params =
        params_for(:price,
          active: false,
          billing_scheme: "billing_scheme",
          metadata: %{key: "value"},
          recurring_aggregate_usage: "recurring_aggregate_usage",
          recurring_interval: "recurring_interval",
          recurring_interval_count: 0,
          recurring_usage_type: "recurring_usage_type",
          tiers_mode: "tiers_mode",
          transform_quantity_divide_by: 1,
          transform_quantity_round: "transform_quantity_round",
          type: "type",
          unit_amount: 1_000,
          unit_amount_decimal: "1000"
        )

      changeset = Price.create_changeset(%Price{}, Map.merge(price_params, %{new_key: "value"}))

      changes_keys = changeset.changes |> Map.keys()

      assert :account_id in changes_keys
      assert :product_id in changes_keys

      assert :active in changes_keys
      assert :billing_scheme in changes_keys
      assert :created_at in changes_keys
      assert :currency in changes_keys
      assert :livemode in changes_keys
      assert :metadata in changes_keys
      assert :nickname in changes_keys
      assert :recurring_aggregate_usage in changes_keys
      assert :recurring_interval in changes_keys
      assert :recurring_interval_count in changes_keys
      assert :recurring_usage_type in changes_keys
      assert :tiers_mode in changes_keys
      assert :transform_quantity_divide_by in changes_keys
      assert :transform_quantity_round in changes_keys
      assert :type in changes_keys
      assert :unit_amount in changes_keys
      assert :unit_amount_decimal in changes_keys
      refute :deleted_at in changes_keys
      refute :new_key in changes_keys
    end

    test "when required params are missing, returns an invalid changeset" do
      changeset = Price.create_changeset(%Price{}, %{active: nil, type: nil})

      refute changeset.valid?
      assert length(changeset.errors) == 6
      assert %{account_id: ["can't be blank"]} = errors_on(changeset)
      assert %{product_id: ["can't be blank"]} = errors_on(changeset)
      assert %{active: ["can't be blank"]} = errors_on(changeset)
      assert %{created_at: ["can't be blank"]} = errors_on(changeset)
      assert %{currency: ["can't be blank"]} = errors_on(changeset)
      assert %{livemode: ["can't be blank"]} = errors_on(changeset)
    end

    test "when params are invalid, returns an invalid changeset" do
      price_params = params_for(:price, currency: "currency", type: "type")

      changeset = Price.create_changeset(%Price{}, price_params)

      refute changeset.valid?
      assert length(changeset.errors) == 1
      assert %{currency: ["is invalid"]} = errors_on(changeset)
    end

    test "when the price has no recurring fields, set the type as one_time" do
      price_params =
        params_for(:price,
          recurring_aggregate_usage: nil,
          recurring_interval: nil,
          recurring_interval_count: nil,
          recurring_usage_type: nil
        )

      changeset = Price.create_changeset(%Price{}, price_params)

      assert get_field(changeset, :type) == Price.types().one_time
    end

    test "when the price has at least one recurring field, set the type as recurring" do
      price_params = params_for(:price, recurring_interval_count: 1)

      changeset = Price.create_changeset(%Price{}, price_params)

      assert get_field(changeset, :type) == Price.types().recurring
    end

    test "when transform_quantity is not right set, returns an invalid changeset" do
      price_params =
        build(:price, transform_quantity_divide_by: nil, transform_quantity_round: nil)
        |> make_type_one_time()
        |> params_for()

      changeset = Price.create_changeset(%Price{}, price_params)

      assert changeset.valid?

      price_params =
        build(:price, transform_quantity_divide_by: 1, transform_quantity_round: "up")
        |> make_type_one_time()
        |> params_for()

      changeset = Price.create_changeset(%Price{}, price_params)

      refute changeset.valid?

      assert %{transform_quantity_divide_by: ["must be greater than or equal to 2"]} =
               errors_on(changeset)

      price_params =
        build(:price, transform_quantity_divide_by: 2, transform_quantity_round: "up")
        |> make_type_one_time()
        |> params_for()

      changeset = Price.create_changeset(%Price{}, price_params)

      assert changeset.valid?

      price_params =
        build(:price, transform_quantity_divide_by: 2, transform_quantity_round: nil)
        |> make_type_one_time()
        |> params_for()

      changeset = Price.create_changeset(%Price{}, price_params)

      refute changeset.valid?
      assert %{transform_quantity_round: ["can't be blank"]} = errors_on(changeset)

      price_params =
        build(:price, transform_quantity_divide_by: nil, transform_quantity_round: "up")
        |> make_type_one_time()
        |> params_for()

      changeset = Price.create_changeset(%Price{}, price_params)

      refute changeset.valid?
      assert %{transform_quantity_divide_by: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "create_changeset/2 - type: one_time" do
    test "default params are rightly set" do
      price_params = build(:price) |> make_type_one_time() |> params_for()

      changeset = Price.create_changeset(%Price{}, price_params)

      assert get_field(changeset, :billing_scheme) == Price.billing_schemes().per_unit
    end

    test "when required params are missing, returns an invalid changeset" do
      price_params =
        build(:price)
        |> make_type_one_time()
        |> Map.merge(%{unit_amount: nil, unit_amount_decimal: nil})
        |> params_for()

      changeset = Price.create_changeset(%Price{}, price_params)

      refute changeset.valid?

      assert %{unit_amount: ["one of [:unit_amount, :unit_amount_decimal] must be present"]} =
               errors_on(changeset)
    end

    test "when params that should be empty are set, returns an invalid changeset" do
      price_params =
        build(:price)
        |> make_type_one_time()
        |> make_tiers_mode_volume()
        |> params_for()

      changeset = Price.create_changeset(%Price{}, price_params)

      refute changeset.valid?
      assert %{tiers_mode: ["can't be set when type is one_time"]} = errors_on(changeset)
    end

    test "when params are invalid, returns an invalid changeset" do
      price_params =
        build(:price)
        |> make_type_one_time()
        |> make_billing_scheme_tiered()
        |> params_for()

      changeset = Price.create_changeset(%Price{}, price_params)

      refute changeset.valid?
      assert %{billing_scheme: ["is invalid when type is one_time"]} = errors_on(changeset)
    end

    test "when params are valid, returns an valid changeset" do
      price_params =
        build(:price)
        |> make_type_one_time()
        |> params_for()

      changeset = Price.create_changeset(%Price{}, price_params)

      assert changeset.valid?
      assert get_field(changeset, :account_id) == price_params.account_id
      assert get_field(changeset, :product_id) == price_params.product_id

      assert get_field(changeset, :active) == true
      assert get_field(changeset, :billing_scheme) == Price.billing_schemes().per_unit
      assert get_field(changeset, :created_at) == price_params.created_at
      assert get_field(changeset, :currency) == price_params.currency
      assert get_field(changeset, :livemode) == price_params.livemode
      assert get_field(changeset, :nickname) == price_params.nickname
      assert is_nil(get_field(changeset, :recurring_aggregate_usage))
      assert is_nil(get_field(changeset, :recurring_interval))
      assert is_nil(get_field(changeset, :recurring_interval_count))
      assert is_nil(get_field(changeset, :recurring_usage_type))
      assert get_field(changeset, :tiers) == []
      assert is_nil(get_field(changeset, :tiers_mode))
      assert get_field(changeset, :type) == price_params.type
      assert get_field(changeset, :unit_amount) == price_params.unit_amount
      assert get_field(changeset, :unit_amount_decimal) == Decimal.new(price_params.unit_amount)
    end
  end

  describe "create_changeset/2 - type: recurring - recurring_usage_type: common for all" do
    test "default params are rightly set" do
      price_params =
        build(:price)
        |> make_type_recurring()
        |> params_for()
        |> Map.merge(%{recurring_interval_count: nil})

      changeset = Price.create_changeset(%Price{}, price_params)

      assert get_field(changeset, :recurring_usage_type) == Price.recurring_usage_types().licensed
      assert get_field(changeset, :recurring_interval_count) == 1
    end

    test "when required params are missing, returns an invalid changeset" do
      price_params =
        build(:price)
        |> make_type_recurring()
        |> params_for()
        |> Map.merge(%{recurring_interval: nil})

      changeset = Price.create_changeset(%Price{}, price_params)

      refute changeset.valid?
      assert %{recurring_interval: ["can't be blank"]} = errors_on(changeset)
    end

    test "when params are invalid, returns an invalid changeset" do
      price_params =
        build(:price)
        |> make_type_recurring()
        |> params_for()
        |> Map.merge(%{recurring_interval: "recurring_interval"})

      changeset = Price.create_changeset(%Price{}, price_params)

      refute changeset.valid?
      assert %{recurring_interval: ["is invalid"]} = errors_on(changeset)
    end
  end

  describe "create_changeset/2 - type: recurring - recurring_usage_type: licensed" do
    test "when params that should be empty are set, returns an invalid changeset" do
      price_params =
        build(:price)
        |> make_type_recurring()
        |> make_recurring_usage_type_licensed()
        |> make_recurring_aggregate_usage_sum()
        |> params_for()

      changeset = Price.create_changeset(%Price{}, price_params)

      refute changeset.valid?

      assert %{recurring_aggregate_usage: ["can't be set when recurring_usage_type is licensed"]} =
               errors_on(changeset)
    end

    test "when params are valid, returns an valid changeset" do
      price_params =
        build(:price)
        |> make_type_recurring()
        |> make_recurring_usage_type_licensed()
        |> make_billing_scheme_per_unit()
        |> params_for()

      changeset = Price.create_changeset(%Price{}, price_params)

      assert changeset.valid?
      assert get_field(changeset, :account_id) == price_params.account_id
      assert get_field(changeset, :product_id) == price_params.product_id

      assert get_field(changeset, :active) == true
      assert get_field(changeset, :billing_scheme) == Price.billing_schemes().per_unit
      assert get_field(changeset, :created_at) == price_params.created_at
      assert get_field(changeset, :currency) == price_params.currency
      assert get_field(changeset, :livemode) == price_params.livemode
      assert get_field(changeset, :nickname) == price_params.nickname
      assert is_nil(get_field(changeset, :recurring_aggregate_usage))
      assert get_field(changeset, :recurring_interval) == price_params.recurring_interval

      assert get_field(changeset, :recurring_interval_count) ==
               price_params.recurring_interval_count

      assert get_field(changeset, :recurring_usage_type) == price_params.recurring_usage_type
      assert get_field(changeset, :tiers) == []
      assert is_nil(get_field(changeset, :tiers_mode))
      assert get_field(changeset, :type) == price_params.type
      assert get_field(changeset, :unit_amount) == price_params.unit_amount
      assert get_field(changeset, :unit_amount_decimal) == Decimal.new(price_params.unit_amount)
    end
  end

  describe "create_changeset/2 - type: recurring - recurring_usage_type: metered" do
    test "default params are rightly set" do
      price_params =
        build(:price)
        |> make_type_recurring()
        |> make_recurring_usage_type_metered()
        |> params_for()

      changeset = Price.create_changeset(%Price{}, price_params)

      assert get_field(changeset, :recurring_aggregate_usage) ==
               Price.recurring_aggregate_usages().sum
    end

    test "when params are invalid, returns an invalid changeset" do
      price_params =
        build(:price)
        |> make_type_recurring()
        |> make_recurring_usage_type_metered()
        |> params_for()
        |> Map.merge(%{recurring_aggregate_usage: "recurring_aggregate_usage"})

      changeset = Price.create_changeset(%Price{}, price_params)

      refute changeset.valid?
      assert %{recurring_aggregate_usage: ["is invalid"]} = errors_on(changeset)
    end

    test "when params are valid, returns an valid changeset" do
      price_params =
        build(:price)
        |> make_type_recurring()
        |> make_recurring_usage_type_metered()
        |> make_billing_scheme_tiered()
        |> params_for()

      changeset = Price.create_changeset(%Price{}, price_params)

      assert changeset.valid?
      assert get_field(changeset, :account_id) == price_params.account_id
      assert get_field(changeset, :product_id) == price_params.product_id

      assert get_field(changeset, :active) == true
      assert get_field(changeset, :billing_scheme) == Price.billing_schemes().tiered
      assert get_field(changeset, :created_at) == price_params.created_at
      assert get_field(changeset, :currency) == price_params.currency
      assert get_field(changeset, :livemode) == price_params.livemode
      assert get_field(changeset, :nickname) == price_params.nickname

      assert get_field(changeset, :recurring_aggregate_usage) ==
               Price.recurring_aggregate_usages().sum

      assert get_field(changeset, :recurring_interval) == price_params.recurring_interval

      assert get_field(changeset, :recurring_interval_count) ==
               price_params.recurring_interval_count

      assert get_field(changeset, :recurring_usage_type) == price_params.recurring_usage_type

      assert get_field(changeset, :tiers) == [
               %PriceTier{
                 flat_amount: nil,
                 flat_amount_decimal: nil,
                 unit_amount: 1000,
                 unit_amount_decimal: Decimal.new(1_000),
                 up_to: 5
               },
               %PriceTier{
                 flat_amount: nil,
                 flat_amount_decimal: nil,
                 unit_amount: 800,
                 unit_amount_decimal: Decimal.new(800),
                 up_to: 10
               },
               %PriceTier{
                 flat_amount: nil,
                 flat_amount_decimal: nil,
                 unit_amount: 600,
                 unit_amount_decimal: Decimal.new(600),
                 up_to: nil
               }
             ]

      assert get_field(changeset, :tiers_mode) == Price.tiers_modes().volume
      assert get_field(changeset, :type) == price_params.type
      assert is_nil(get_field(changeset, :unit_amount))
      assert is_nil(get_field(changeset, :unit_amount_decimal))
    end
  end

  describe "create_changeset/2 - type: recurring - recurring_usage_type: rated" do
    test "when params that should be empty are set, returns an invalid changeset" do
      price_params =
        build(:price)
        |> make_type_recurring()
        |> make_recurring_usage_type_rated()
        |> make_recurring_aggregate_usage_sum()
        |> make_billing_scheme_tiered()
        |> make_tiers_mode_volume()
        |> params_for()
        |> Map.merge(%{unit_amount: 1_000, unit_amount_decimal: "1000"})

      changeset = Price.create_changeset(%Price{}, price_params)

      refute changeset.valid?

      assert %{billing_scheme: ["can't be set when recurring_usage_type is rated"]} =
               errors_on(changeset)

      assert %{unit_amount: ["can't be set when recurring_usage_type is rated"]} =
               errors_on(changeset)

      assert %{unit_amount_decimal: ["can't be set when recurring_usage_type is rated"]} =
               errors_on(changeset)

      assert %{tiers_mode: ["can't be set when recurring_usage_type is rated"]} =
               errors_on(changeset)

      assert %{recurring_aggregate_usage: ["can't be set when recurring_usage_type is rated"]} =
               errors_on(changeset)
    end
  end

  describe "create_changeset/2 - type: recurring - recurring_usage_type: licensed or metered - billing_scheme: common for all" do
    test "default params are rightly set" do
      price_params =
        build(:price)
        |> make_type_recurring()
        |> make_recurring_usage_type_licensed()
        |> params_for()
        |> Map.merge(%{billing_scheme: nil})

      changeset = Price.create_changeset(%Price{}, price_params)

      assert get_field(changeset, :billing_scheme) == Price.billing_schemes().per_unit
    end

    test "when params are invalid, returns an invalid changeset" do
      price_params =
        build(:price)
        |> make_type_recurring()
        |> make_recurring_usage_type_licensed()
        |> params_for()
        |> Map.merge(%{billing_scheme: "billing_scheme"})

      changeset = Price.create_changeset(%Price{}, price_params)

      refute changeset.valid?
      assert %{billing_scheme: ["is invalid"]} = errors_on(changeset)
    end
  end

  describe "create_changeset/2 - type: recurring - recurring_usage_type: licensed or metered - billing_scheme: per_unit" do
    test "when required params are missing, returns an invalid changeset" do
      price_params =
        build(:price)
        |> make_type_recurring()
        |> make_recurring_usage_type_licensed()
        |> make_billing_scheme_per_unit()
        |> params_for()
        |> Map.merge(%{unit_amount: nil, unit_amount_decimal: nil})

      changeset = Price.create_changeset(%Price{}, price_params)

      refute changeset.valid?

      assert %{unit_amount: ["one of [:unit_amount, :unit_amount_decimal] must be present"]} =
               errors_on(changeset)
    end

    test "when params that should be empty are set, returns an invalid changeset" do
      price_params =
        build(:price)
        |> make_type_recurring()
        |> make_recurring_usage_type_licensed()
        |> make_billing_scheme_per_unit()
        |> make_tiers_mode_volume()
        |> params_for()

      changeset = Price.create_changeset(%Price{}, price_params)

      refute changeset.valid?

      assert %{tiers_mode: ["can't be set when billing_scheme is per_unit"]} =
               errors_on(changeset)
    end
  end

  describe "create_changeset/2 - type: recurring - recurring_usage_type: licensed or metered - billing_scheme: tiered" do
    test "when required params are missing, returns an invalid changeset" do
      price_params =
        build(:price)
        |> make_type_recurring()
        |> make_recurring_usage_type_licensed()
        |> make_billing_scheme_tiered()
        |> params_for()
        |> Map.merge(%{tiers_mode: nil, tiers: []})

      changeset = Price.create_changeset(%Price{}, price_params)

      refute changeset.valid?

      assert %{tiers_mode: ["can't be blank"]} = errors_on(changeset)
      assert %{tiers: ["can't be blank when billing_scheme is tiered"]} = errors_on(changeset)
    end

    test "when params that should be empty are set, returns an invalid changeset" do
      price_params =
        build(:price)
        |> make_type_recurring()
        |> make_recurring_usage_type_licensed()
        |> make_billing_scheme_tiered()
        |> params_for()
        |> Map.merge(%{unit_amount: 1000, unit_amount_decimal: "1000"})

      changeset = Price.create_changeset(%Price{}, price_params)

      refute changeset.valid?

      assert %{unit_amount: ["can't be set when billing_scheme is tiered"]} = errors_on(changeset)

      assert %{unit_amount_decimal: ["can't be set when billing_scheme is tiered"]} =
               errors_on(changeset)
    end

    test "when params are invalid, returns an invalid changeset" do
      price_params =
        build(:price)
        |> make_type_recurring()
        |> make_recurring_usage_type_licensed()
        |> make_billing_scheme_tiered()
        |> params_for()
        |> Map.merge(%{tiers_mode: "tiers_mode", tiers: nil})

      changeset = Price.create_changeset(%Price{}, price_params)

      refute changeset.valid?

      assert %{tiers_mode: ["is invalid"]} = errors_on(changeset)
      assert %{tiers: ["is invalid"]} = errors_on(changeset)
    end

    test "when one of tiers is invalid, returns an invalid changeset" do
      price_params =
        build(:price)
        |> make_type_recurring()
        |> make_recurring_usage_type_licensed()
        |> make_billing_scheme_tiered()
        |> params_for()
        |> Map.merge(%{tiers: [params_for(:price_tier, up_to: 0)]})

      changeset = Price.create_changeset(%Price{}, price_params)

      refute changeset.valid?

      assert %{tiers: [%{up_to: ["must be greater than 0"]}]} = errors_on(changeset)
    end

    test "when up_to of the tiers are not uniq, returns an invalid changeset" do
      price_params =
        build(:price)
        |> make_type_recurring()
        |> make_recurring_usage_type_licensed()
        |> make_billing_scheme_tiered()
        |> params_for()
        |> Map.merge(%{
          tiers: [
            params_for(:price_tier, unit_amount: 1000, up_to: nil),
            params_for(:price_tier, unit_amount: 1000, up_to: nil)
          ]
        })

      changeset = Price.create_changeset(%Price{}, price_params)

      refute changeset.valid?

      assert %{tiers: ["must be uniq"]} = errors_on(changeset)
    end

    test "when tiers are not sorted according to up_to, returns an invalid changeset" do
      price_params =
        build(:price)
        |> make_type_recurring()
        |> make_recurring_usage_type_licensed()
        |> make_billing_scheme_tiered()
        |> params_for()
        |> Map.merge(%{
          tiers: [
            params_for(:price_tier, unit_amount: 1000, up_to: nil),
            params_for(:price_tier, unit_amount: 1000, up_to: 1)
          ]
        })

      changeset = Price.create_changeset(%Price{}, price_params)

      refute changeset.valid?

      assert %{tiers: ["must be sorted ascending by the up_to param"]} = errors_on(changeset)
    end
  end

  describe "updade_changeset/2" do
    test "only permitted_keys are casted" do
      price = insert!(:price)

      price_params = params_for(:price, active: false, metadata: %{key: "value"})

      changeset = Price.update_changeset(price, Map.merge(price_params, %{new_key: "value"}))

      changes_keys = changeset.changes |> Map.keys()
      assert length(changes_keys) == 3

      assert :active in changes_keys
      assert :metadata in changes_keys
      assert :nickname in changes_keys
    end

    test "when required params are missing, returns an invalid changeset" do
      price = insert!(:price)

      changeset = Price.create_changeset(price, %{active: nil})

      refute changeset.valid?
      assert length(changeset.errors) == 1
      assert %{active: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "delete_changeset/2" do
    test "when deleted_at is valid, returns an valid changeset" do
      price = insert!(:price)
      utc_now = utc_now()

      changeset = Price.delete_changeset(price, %{deleted_at: utc_now})

      assert changeset.valid?
      assert get_field(changeset, :deleted_at) == utc_now
    end

    test "when deleted_at is nil, returns an invalid changeset" do
      price = insert!(:price)

      changeset = Price.delete_changeset(price, %{})

      refute changeset.valid?
      assert %{deleted_at: ["can't be blank"]} = errors_on(changeset)
    end

    test "when deleted_at is before created_at, returns an invalid changeset" do
      price = insert!(:price)

      changeset = Price.delete_changeset(price, %{deleted_at: price.created_at |> add(-1200)})

      refute changeset.valid?
      assert %{deleted_at: ["should be after or equal to created_at"]} = errors_on(changeset)
    end
  end
end
