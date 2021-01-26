defmodule Tailcall.Billing.TaxRates.TaxRateTest do
  use ExUnit.Case, async: true
  use Tailcall.DataCase

  alias Tailcall.Billing.TaxRates.TaxRate

  describe "create_changeset/2" do
    test "only permitted_keys are casted" do
      tax_rate_params = build(:tax_rate) |> make_inactive() |> params_for()

      changeset =
        TaxRate.create_changeset(%TaxRate{}, Map.merge(tax_rate_params, %{new_key: "value"}))

      changes_keys = changeset.changes |> Map.keys()

      assert :account_id in changes_keys
      assert :active in changes_keys
      assert :created_at in changes_keys
      assert :description in changes_keys
      assert :display_name in changes_keys
      assert :inclusive in changes_keys
      assert :jurisdiction in changes_keys
      assert :livemode in changes_keys
      assert :metadata in changes_keys
      assert :percentage in changes_keys
      refute :deleted_at in changes_keys
      refute :new_key in changes_keys
    end

    test "when all params are valid, returns an valid changeset" do
      tax_rate_params = params_for(:tax_rate)

      changeset = TaxRate.create_changeset(%TaxRate{}, tax_rate_params)

      assert changeset.valid?
      assert get_field(changeset, :account_id) == tax_rate_params.account_id
      assert get_field(changeset, :active) == tax_rate_params.active
      assert get_field(changeset, :created_at) == tax_rate_params.created_at
      assert get_field(changeset, :description) == tax_rate_params.description
      assert get_field(changeset, :display_name) == tax_rate_params.display_name
      assert get_field(changeset, :inclusive) == tax_rate_params.inclusive
      assert get_field(changeset, :jurisdiction) == tax_rate_params.jurisdiction
      assert get_field(changeset, :livemode) == tax_rate_params.livemode
      assert get_field(changeset, :metadata) == tax_rate_params.metadata

      assert get_field(changeset, :percentage) ==
               Decimal.new(to_string(tax_rate_params.percentage))
    end

    test "when required params are missing, returns an invalid changeset" do
      changeset = TaxRate.create_changeset(%TaxRate{}, %{active: nil})

      refute changeset.valid?
      assert length(changeset.errors) == 7
      assert %{account_id: ["can't be blank"]} = errors_on(changeset)
      assert %{active: ["can't be blank"]} = errors_on(changeset)
      assert %{created_at: ["can't be blank"]} = errors_on(changeset)
      assert %{display_name: ["can't be blank"]} = errors_on(changeset)
      assert %{inclusive: ["can't be blank"]} = errors_on(changeset)
      assert %{livemode: ["can't be blank"]} = errors_on(changeset)
      assert %{percentage: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "updade_changeset/2" do
    test "only permitted_keys are casted" do
      tax_rate = insert!(:tax_rate)

      tax_rate_params = build(:tax_rate, jurisdiction: "IL") |> make_inactive() |> params_for()

      changeset =
        TaxRate.update_changeset(tax_rate, Map.merge(tax_rate_params, %{new_key: "value"}))

      changes_keys = changeset.changes |> Map.keys()

      refute :account_id in changes_keys
      refute :livemode in changes_keys
      assert :active in changes_keys
      assert :description in changes_keys
      assert :display_name in changes_keys
      refute :inclusive in changes_keys
      assert :jurisdiction in changes_keys
      refute :percentage in changes_keys
      refute :deleted_at in changes_keys
      refute :new_key in changes_keys
    end
  end

  describe "delete_changeset/2" do
    test "when deleted_at is valid, returns an valid changeset" do
      tax_rate = insert!(:tax_rate)

      utc_now = utc_now()

      changeset = TaxRate.delete_changeset(tax_rate, %{deleted_at: utc_now})

      assert changeset.valid?
      assert get_field(changeset, :deleted_at) == utc_now
    end

    test "when deleted_at is nil, returns an invalid changeset" do
      tax_rate = insert!(:tax_rate)

      changeset = TaxRate.delete_changeset(tax_rate, %{})

      refute changeset.valid?
      assert %{deleted_at: ["can't be blank"]} = errors_on(changeset)
    end

    test "when deleted_at is before created_at, returns an invalid changeset" do
      tax_rate = insert!(:tax_rate, created_at: utc_now())

      changeset = TaxRate.delete_changeset(tax_rate, %{deleted_at: utc_now() |> add(-1200)})

      refute changeset.valid?

      assert %{deleted_at: ["should be after or equal to created_at"]} = errors_on(changeset)
    end
  end
end
