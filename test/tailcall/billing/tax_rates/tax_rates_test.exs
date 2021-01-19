defmodule Tailcall.Billing.TaxRatesTest do
  use ExUnit.Case, async: true
  use Tailcall.DataCase

  alias Tailcall.Billing.TaxRates
  alias Tailcall.Billing.TaxRates.TaxRate

  describe "create_tax_rate/1" do
    test "when data is valid, creates the tax_rate" do
      tax_rate_params = params_for(:tax_rate)

      assert {:ok, %TaxRate{} = tax_rate} = TaxRates.create_tax_rate(tax_rate_params)
      assert tax_rate.display_name == tax_rate_params.display_name
    end

    test "with invalid data, returns an error tuple with an invalid changeset" do
      tax_rate_params = params_for(:tax_rate, display_name: nil)

      assert {:error, changeset} = TaxRates.create_tax_rate(tax_rate_params)

      refute changeset.valid?
    end

    test "when user does not exist, returns an error tuple with an invalid changeset" do
      tax_rate_params = params_for(:tax_rate, user_id: id())

      assert {:error, changeset} = TaxRates.create_tax_rate(tax_rate_params)

      refute changeset.valid?
      assert %{user: ["does not exist"]} = errors_on(changeset)
    end
  end

  describe "get_tax_rate/1" do
    test "when tax_rate does not exist, returns nil" do
      assert is_nil(TaxRates.get_tax_rate(shortcode_id()))
    end

    test "when tax_rate exists, returns the tax_rate" do
      tax_rate_factory = insert!(:tax_rate)

      tax_rate = TaxRates.get_tax_rate(tax_rate_factory.id)
      assert %TaxRate{} = tax_rate
      assert tax_rate.id == tax_rate_factory.id
    end
  end

  describe "update_tax_rate/2" do
    test "when tax_rate is soft deleted, raise a FunctionClauseError" do
      tax_rate = build(:tax_rate) |> make_deleted() |> insert!()

      assert_raise FunctionClauseError, fn ->
        TaxRates.update_tax_rate(tax_rate, %{active: false})
      end
    end

    test "when data is valid, update the tax_rate" do
      tax_rate = build(:tax_rate) |> make_active() |> insert!()

      {:ok, %TaxRate{} = tax_rate} = TaxRates.update_tax_rate(tax_rate, %{active: false})
      assert tax_rate.active == false
    end
  end

  describe "delete_tax_rate/2" do
    test "when tax_rate is soft deleted, raise a FunctionClauseError" do
      tax_rate = build(:tax_rate) |> make_deleted() |> insert!()

      assert_raise FunctionClauseError, fn ->
        TaxRates.delete_tax_rate(tax_rate, %{deleted_at: utc_now()})
      end
    end

    test "when data is valid, delete the tax_rate" do
      tax_rate = build(:tax_rate) |> make_active() |> insert!()
      datetime = utc_now()

      {:ok, %TaxRate{} = tax_rate} = TaxRates.delete_tax_rate(tax_rate, %{deleted_at: datetime})
      assert tax_rate.deleted_at == datetime
    end
  end
end
