defmodule Tailcall.Core.CustomersTest do
  use ExUnit.Case, async: true
  use Tailcall.DataCase

  alias Tailcall.Core.Customers
  alias Tailcall.Core.Customers.Customer

  describe "list_customers/1" do
    test "list_customers" do
      %{id: customer_id} = insert!(:customer)

      assert %{total: 1, data: [%{id: ^customer_id}]} = Customers.list_customers()
    end

    test "order_by" do
      %{id: id1} = insert!(:customer)
      %{id: id2} = insert!(:customer)

      assert %{data: [%{id: ^id2}, %{id: ^id1}]} = Customers.list_customers()

      assert %{data: [%{id: ^id1}, %{id: ^id2}]} =
               Customers.list_customers(order_by_fields: [asc: :id])
    end

    test "filters" do
      customer = insert!(:customer)

      [
        [id: customer.id],
        [id: [customer.id]],
        [account_id: customer.account_id],
        [email: customer.email],
        [livemode: customer.livemode],
        [name: customer.name],
        [ongoing_at: customer.created_at]
      ]
      |> Enum.each(fn filter ->
        assert %{total: 1, data: [_customer]} = Customers.list_customers(filters: filter)
      end)

      [
        [id: shortcode_id()],
        [id: [shortcode_id()]],
        [account_id: shortcode_id()],
        [email: "non existing email"],
        [livemode: !customer.livemode],
        [name: "non existing name"],
        [ongoing_at: customer.created_at |> add(-1200)],
        [deleted_at: customer.created_at |> add(-1200)]
      ]
      |> Enum.each(fn filter ->
        assert %{total: 0, data: []} = Customers.list_customers(filters: filter)
      end)
    end
  end

  describe "create_customer/1" do
    test "when data is valid, creates the customer" do
      customer_params = params_for(:customer)

      assert {:ok, %Customer{}} = Customers.create_customer(customer_params)
    end

    test "when data is invalid, returns an error tuple with an invalid changeset" do
      assert {:error, changeset} = Customers.create_customer(%{})

      refute changeset.valid?
    end
  end

  describe "get_customer/1" do
    test "when the customer exists, returns the customer" do
      %{id: customer_id} = insert!(:customer)

      assert %Customer{id: ^customer_id} = Customers.get_customer(customer_id)
    end

    test "when customer does not exist, returns nil" do
      assert is_nil(Customers.get_customer(shortcode_id()))
    end
  end

  describe "get_customer!/1" do
    test "when the customer exists, returns the customer" do
      %{id: customer_id} = insert!(:customer)

      assert %Customer{id: ^customer_id} = Customers.get_customer!(customer_id)
    end

    test "when customer does not exist, raises a Ecto.NoResultsError" do
      assert_raise Ecto.NoResultsError, fn ->
        Customers.get_customer!(shortcode_id())
      end
    end
  end

  describe "customer_exists?/1" do
    test "when the customer exists, returns true" do
      customer = insert!(:customer)
      assert Customers.customer_exists?(customer.id)
    end

    test "when customer does not exist, returns false" do
      refute Customers.customer_exists?(shortcode_id())
    end
  end

  describe "update_customer/2" do
    test "when data is valid, updates the customer" do
      customer_factory = insert!(:customer)

      customer_params = params_for(:customer)

      assert {:ok, %Customer{} = customer} =
               Customers.update_customer(customer_factory, customer_params)

      assert customer.name == customer_params.name
    end

    test "when data is invalid, returns an invalid changeset" do
      customer = insert!(:customer)

      assert {:error, changeset} = Customers.update_customer(customer, %{balance: nil})

      refute changeset.valid?
    end

    test "when customer is soft deleted, raises a FunctionClauseError" do
      customer = build(:customer) |> make_deleted() |> insert!()

      assert_raise FunctionClauseError, fn ->
        Customers.update_customer(customer, %{})
      end
    end
  end

  describe "delete_customer/2" do
    test "when data is valid, soft delete the customer" do
      customer = insert!(:customer)
      utc_now = utc_now()
      assert {:ok, %Customer{deleted_at: ^utc_now}} = Customers.delete_customer(customer, utc_now)
    end

    test "when data is invalid, returns an invalid changeset" do
      customer = insert!(:customer)

      assert {:error, changeset} =
               Customers.delete_customer(customer, customer.created_at |> add(-1200))

      refute changeset.valid?
    end

    test "when customer is soft deleted, raises a FunctionClauseError" do
      customer = build(:customer) |> make_deleted() |> insert!()

      assert_raise FunctionClauseError, fn ->
        Customers.delete_customer(customer, utc_now())
      end
    end
  end
end
