defmodule Tailcall.Core.Customers.CustomerTest do
  use ExUnit.Case, async: true
  use Tailcall.DataCase

  alias Tailcall.Core.Customers.Customer

  describe "create_changeset/2" do
    test "only permitted_keys are casted" do
      customer_params =
        params_for(:customer,
          balance: 10,
          next_invoice_sequence: 10,
          metadata: %{key: "value"},
          preferred_locales: ["a"],
          tax_exempt: "exempt"
        )

      changeset =
        Customer.create_changeset(%Customer{}, Map.merge(customer_params, %{new_key: "value"}))

      changes_keys = changeset.changes |> Map.keys()

      assert :account_id in changes_keys
      assert :balance in changes_keys
      assert :currency in changes_keys
      assert :created_at in changes_keys
      refute :delinquent in changes_keys
      assert :description in changes_keys
      assert :email in changes_keys
      assert :invoice_prefix in changes_keys
      assert :invoice_settings in changes_keys
      assert :livemode in changes_keys
      assert :metadata in changes_keys
      assert :name in changes_keys
      assert :next_invoice_sequence in changes_keys
      assert :phone in changes_keys
      assert :preferred_locales in changes_keys
      assert :tax_exempt in changes_keys
      refute :deleted_at in changes_keys
      refute :new_key in changes_keys
    end

    test "when all params are valid, returns an valid changeset" do
      customer_params = params_for(:customer)

      changeset = Customer.create_changeset(%Customer{}, customer_params)

      assert changeset.valid?
    end

    test "when required params are missing, returns an invalid changeset" do
      changeset = Customer.create_changeset(%Customer{}, %{})

      refute changeset.valid?
      assert %{account_id: ["can't be blank"]} = errors_on(changeset)
      assert %{created_at: ["can't be blank"]} = errors_on(changeset)
      assert %{livemode: ["can't be blank"]} = errors_on(changeset)
    end

    test "when tax_exempt is not valid, returns an invalid changeset" do
      customer_params = params_for(:customer, tax_exempt: "tax_exempt")

      changeset = Customer.create_changeset(%Customer{}, customer_params)

      refute changeset.valid?
      assert %{tax_exempt: ["is invalid"]} = errors_on(changeset)
    end

    test "when next_invoice_sequence is not valid, returns an invalid changeset" do
      customer_params = params_for(:customer, next_invoice_sequence: 0)

      changeset = Customer.create_changeset(%Customer{}, customer_params)

      refute changeset.valid?

      assert %{next_invoice_sequence: ["must be greater than or equal to 1"]} =
               errors_on(changeset)
    end
  end

  describe "updade_changeset/2" do
    test "only permitted_keys are casted" do
      customer = insert!(:customer)

      customer_params =
        params_for(:customer,
          balance: 10,
          delinquent: !customer.delinquent,
          metadata: %{key: "value"},
          next_invoice_sequence: 10,
          preferred_locales: ["fr"],
          tax_exempt: "exempt"
        )

      changeset =
        Customer.update_changeset(customer, Map.merge(customer_params, %{new_key: "value"}))

      changes_keys = changeset.changes |> Map.keys()

      refute :account_id in changes_keys
      assert :balance in changes_keys
      refute :currency in changes_keys
      refute :created_at in changes_keys
      assert :delinquent in changes_keys
      assert :description in changes_keys
      assert :email in changes_keys
      assert :invoice_prefix in changes_keys
      assert :metadata in changes_keys
      assert :name in changes_keys
      assert :next_invoice_sequence in changes_keys
      assert :phone in changes_keys
      assert :preferred_locales in changes_keys
      assert :tax_exempt in changes_keys
      refute :deleted_at in changes_keys
      refute :new_key in changes_keys
    end

    test "when params are valid, returns an valid changeset" do
      customer = insert!(:customer)

      customer_params =
        params_for(:customer,
          balance: 10,
          tax_exempt: Customer.tax_exempts().exempt,
          delinquent: true,
          metadata: %{key: "value"}
        )

      changeset = Customer.update_changeset(customer, customer_params)

      assert changeset.valid?
      assert get_field(changeset, :balance) == customer_params.balance
      assert get_field(changeset, :delinquent) == customer_params.delinquent
      assert get_field(changeset, :description) == customer_params.description
      assert get_field(changeset, :email) == customer_params.email
      assert get_field(changeset, :invoice_prefix) == customer_params.invoice_prefix
      assert get_field(changeset, :metadata) == customer_params.metadata
      assert get_field(changeset, :name) == customer_params.name
      assert get_field(changeset, :next_invoice_sequence) == customer_params.next_invoice_sequence
      assert get_field(changeset, :phone) == customer_params.phone
      assert get_field(changeset, :preferred_locales) == customer_params.preferred_locales
      assert get_field(changeset, :tax_exempt) == customer_params.tax_exempt
    end

    test "when required params are missing, returns an invalid changeset" do
      customer = insert!(:customer)

      changeset = Customer.update_changeset(customer, %{balance: nil, next_invoice_sequence: nil})

      refute changeset.valid?
      assert %{balance: ["can't be blank"]} = errors_on(changeset)
      assert %{next_invoice_sequence: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "delete_changeset/2" do
    test "when deleted_at is valid, returns an valid changeset" do
      customer = insert!(:customer)

      utc_now = utc_now()

      changeset = Customer.delete_changeset(customer, %{deleted_at: utc_now})

      assert changeset.valid?
      assert get_field(changeset, :deleted_at) == utc_now
    end

    test "when deleted_at is nil, returns an invalid changeset" do
      customer = insert!(:customer)

      changeset = Customer.delete_changeset(customer, %{})

      refute changeset.valid?
      assert %{deleted_at: ["can't be blank"]} = errors_on(changeset)
    end

    test "when deleted_at is before created_at, returns an invalid changeset" do
      customer = insert!(:customer, created_at: utc_now())

      changeset = Customer.delete_changeset(customer, %{deleted_at: utc_now() |> add(-1200)})

      refute changeset.valid?

      assert %{deleted_at: ["should be after or equal to created_at"]} = errors_on(changeset)
    end
  end
end
