defmodule Tailcall.Core.Customers.CustomerTest do
  use ExUnit.Case, async: true
  use Tailcall.DataCase

  alias Tailcall.Core.Customers.Customer

  describe "create_changeset/2" do
    test "only permitted_keys are casted" do
      customer_params = params_for(:customer, tax_exempt: "exempt", invoice_prefix: "AAA")

      changeset =
        Customer.create_changeset(%Customer{}, Map.merge(customer_params, %{new_key: "value"}))

      changes_keys = changeset.changes |> Map.keys()

      assert :user_id in changes_keys
      assert :livemode in changes_keys
      assert :name in changes_keys
      assert :email in changes_keys
      assert :phone in changes_keys
      assert :currency in changes_keys
      assert :invoice_prefix in changes_keys
      assert :tax_exempt in changes_keys
      refute :deleted_at in changes_keys
      refute :new_key in changes_keys
    end

    test "when required params are missing, returns an invalid changeset" do
      customer_params =
        params_for(:customer,
          user_id: nil,
          livemode: nil
        )

      changeset = Customer.create_changeset(%Customer{}, customer_params)

      refute changeset.valid?
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
      assert %{livemode: ["can't be blank"]} = errors_on(changeset)
    end

    test "when tax_exempt is not valid, returns an invalid changeset" do
      customer_params = params_for(:customer, tax_exempt: "tax_exempt")

      changeset = Customer.create_changeset(%Customer{}, customer_params)

      refute changeset.valid?
      assert %{tax_exempt: ["is invalid"]} = errors_on(changeset)
    end

    test "when all params are valid, returns an valid changeset" do
      customer_params = params_for(:customer)

      changeset = Customer.create_changeset(%Customer{}, customer_params)

      assert changeset.valid?
    end
  end

  describe "updade_changeset/2" do
    test "only permitted_keys are casted" do
      customer = insert(:customer)

      customer_params = params_for(:customer, tax_exempt: "exempt")

      changeset =
        Customer.update_changeset(customer, Map.merge(customer_params, %{new_key: "value"}))

      changes_keys = changeset.changes |> Map.keys()

      refute :user_id in changes_keys
      refute :livemode in changes_keys
      assert :name in changes_keys
      assert :email in changes_keys
      assert :phone in changes_keys
      assert :tax_exempt in changes_keys
      refute :deleted_at in changes_keys
      refute :new_key in changes_keys
    end
  end

  describe "delete_changeset/2" do
    test "when deleted_at is nil, returns an invalid changeset" do
      customer = insert(:customer)

      changeset = Customer.delete_changeset(customer, %{})

      refute changeset.valid?
      assert %{deleted_at: ["can't be blank"]} = errors_on(changeset)
    end

    test "when deleted_at is valid, returns an valid changeset" do
      customer = insert(:customer)

      changeset = Customer.delete_changeset(customer, %{deleted_at: @datetime_1})

      assert changeset.valid?
    end
  end
end
