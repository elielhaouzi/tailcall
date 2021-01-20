defmodule Tailcall.Billing.ProductsTest do
  use ExUnit.Case, async: true
  use Tailcall.DataCase

  alias Tailcall.Billing.Products
  alias Tailcall.Billing.Products.Product

  describe "list_products/1" do
    test "list products" do
      %{id: product_id} = insert!(:product)

      assert %{total: 1, data: [%{id: ^product_id}]} = Products.list_products()
    end

    test "order_by" do
      %{id: id1} = insert!(:product)
      %{id: id2} = insert!(:product)

      assert %{data: [%{id: ^id1}, %{id: ^id2}]} = Products.list_products()

      assert %{data: [%{id: ^id2}, %{id: ^id1}]} =
               Products.list_products(order_by_fields: [desc: :id])
    end

    test "filters" do
      product = insert!(:product)

      [
        [id: product.id],
        [id: [product.id]],
        [user_id: product.user_id],
        [active: product.active],
        [livemode: product.livemode],
        [name: product.name],
        [type: product.type],
        [ongoing_at: product.created_at]
      ]
      |> Enum.each(fn filter ->
        assert %{total: 1, data: [_product]} = Products.list_products(filters: filter)
      end)

      [
        [id: shortcode_id()],
        [user_id: shortcode_id()],
        [active: !product.active],
        [livemode: !product.livemode],
        [name: "name"],
        [type: "type"],
        [ongoing_at: product.created_at |> add(-1200)]
      ]
      |> Enum.each(fn filter ->
        assert %{total: 0, data: []} = Products.list_products(filters: filter)
      end)
    end
  end

  describe "create_product/1" do
    test "when data is valid, creates the product" do
      product_params = params_for(:product)

      assert {:ok, %Product{}} = Products.create_product(product_params)
    end

    test "with invalid data, returns an error tuple with an invalid changeset" do
      product_params = params_for(:product, name: nil)

      assert {:error, changeset} = Products.create_product(product_params)

      refute changeset.valid?
    end

    test "when user does not exist, returns an error tuple with an invalid changeset" do
      product_params = params_for(:product, user_id: shortcode_id())

      assert {:error, changeset} = Products.create_product(product_params)

      refute changeset.valid?
      assert %{user: ["does not exist"]} = errors_on(changeset)
    end
  end

  describe "get_product/1" do
    test "when product exists, returns the product" do
      %{id: id} = insert!(:product)

      assert %Product{id: ^id} = Products.get_product(id)
    end

    test "when product does not exist, returns nil" do
      assert is_nil(Products.get_product(shortcode_id()))
    end
  end

  describe "get_product!/1" do
    test "when product exists, returns the product" do
      %{id: id} = insert!(:product)

      assert %Product{id: ^id} = Products.get_product!(id)
    end

    test "when product does not exist, returns nil" do
      assert_raise Ecto.NoResultsError, fn ->
        Products.get_product!(shortcode_id())
      end
    end
  end

  describe "update_product/2" do
    test "when data is valid, update the product" do
      product = build(:product) |> make_active() |> insert!()

      {:ok, %Product{} = product} = Products.update_product(product, %{active: false})
      assert product.active == false
    end

    test "when data is invalid, returns an error tuple with an invalid changeset" do
      product = build(:product) |> make_active() |> insert!()

      {:error, %Ecto.Changeset{} = changeset} = Products.update_product(product, %{active: nil})
      refute changeset.valid?
    end

    test "when product is soft deleted, raise a FunctionClauseError" do
      product = build(:product) |> make_deleted() |> insert!()

      assert_raise FunctionClauseError, fn ->
        Products.update_product(product, %{active: false})
      end
    end
  end

  describe "delete_product/2" do
    test "with a valid product, soft delete the product" do
      product_factory = insert!(:product)
      delete_at = utc_now()

      assert {:ok, %Product{} = product} = Products.delete_product(product_factory, delete_at)
      assert product.deleted_at == delete_at
    end

    test "when product is soft deleted, raises a FunctionClauseError" do
      product = build(:product) |> make_deleted() |> insert!()

      assert_raise FunctionClauseError, fn ->
        Products.delete_product(product, utc_now())
      end
    end

    test "when deleted_at is before created_at, returns an ecto changeset error" do
      product = insert!(:product)

      assert {:error, changeset} =
               Products.delete_product(product, product.created_at |> add(-1200))

      refute changeset.valid?
      assert %{deleted_at: ["should be after or equal to created_at"]} = errors_on(changeset)
    end
  end
end
