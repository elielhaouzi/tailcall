defmodule Tailcall.Billing.PricesTest do
  use ExUnit.Case, async: true
  use Tailcall.DataCase

  alias Tailcall.Billing.Prices
  alias Tailcall.Billing.Prices.Price

  describe "list_prices/1" do
    test "list prices" do
      %{id: price_id} = insert!(:price)

      assert %{total: 1, data: [%{id: ^price_id}]} = Prices.list_prices()
    end

    test "order_by" do
      %{id: id1} = insert!(:price)
      %{id: id2} = insert!(:price)

      assert %{data: [%{id: ^id1}, %{id: ^id2}]} = Prices.list_prices()

      assert %{data: [%{id: ^id2}, %{id: ^id1}]} =
               Prices.list_prices(order_by_fields: [desc: :id])
    end

    test "filters" do
      price = insert!(:price)

      [
        [id: price.id],
        [id: [price.id]],
        [account_id: price.account_id],
        [product_id: price.product_id],
        [active: price.active],
        [currency: price.currency],
        [livemode: price.livemode],
        [type: price.type],
        [ongoing_at: price.created_at]
      ]
      |> Enum.each(fn filter ->
        assert %{total: 1, data: [_price]} = Prices.list_prices(filters: filter)
      end)

      [
        [id: shortcode_id()],
        [account_id: shortcode_id()],
        [product_id: shortcode_id()],
        [active: !price.active],
        [currency: "currency"],
        [livemode: !price.livemode],
        [type: "type"],
        [ongoing_at: price.created_at |> add(-1200)],
        [deleted_at: price.created_at |> add(-1200)]
      ]
      |> Enum.each(fn filter ->
        assert %{total: 0, data: []} = Prices.list_prices(filters: filter)
      end)
    end

    test "includes" do
      insert!(:price)

      %{data: [price], total: 1} = Prices.list_prices()
      refute Ecto.assoc_loaded?(price.tiers)

      %{data: [price], total: 1} = Prices.list_prices(includes: [:tiers])
      assert Ecto.assoc_loaded?(price.tiers)
    end
  end

  describe "create_price/1" do
    test "when data is valid, creates the price" do
      price_params = build(:price) |> make_type_one_time() |> params_for()

      assert {:ok, %Price{}} = Prices.create_price(price_params)
    end

    test "with invalid data, returns an error tuple with an invalid changeset" do
      assert {:error, changeset} = Prices.create_price(%{})

      refute changeset.valid?
    end

    test "when account does not exist, returns an error tuple with an invalid changeset" do
      price_params =
        build(:price, account_id: shortcode_id()) |> make_type_one_time() |> params_for()

      assert {:error, changeset} = Prices.create_price(price_params)

      refute changeset.valid?
      assert %{account: ["does not exist"]} = errors_on(changeset)
    end

    test "when product does not exist, returns an error tuple with an invalid changeset" do
      price_params =
        build(:price, product_id: shortcode_id()) |> make_type_one_time() |> params_for()

      assert {:error, changeset} = Prices.create_price(price_params)

      refute changeset.valid?
      assert %{product: ["does not exist"]} = errors_on(changeset)
    end
  end

  describe "get_price/1" do
    test "when price exists, returns the price" do
      %{id: id} = insert!(:price)

      assert %Price{id: ^id} = Prices.get_price(id)
    end

    test "when price does not exist, returns nil" do
      assert is_nil(Prices.get_price(shortcode_id()))
    end
  end

  describe "get_price!/1" do
    test "when price exists, returns the price" do
      %{id: id} = insert!(:price)

      assert %Price{id: ^id} = Prices.get_price!(id)
    end

    test "when price does not exist, returns nil" do
      assert_raise Ecto.NoResultsError, fn ->
        Prices.get_price!(shortcode_id())
      end
    end
  end

  describe "update_price/2" do
    test "when data is valid, update the price" do
      price = insert!(:price, active: true)

      {:ok, %Price{} = price} = Prices.update_price(price, %{active: false})
      assert price.active == false
    end

    test "when plan is soft deleted, raise a FunctionClauseError" do
      price = build(:price) |> make_deleted() |> make_type_one_time() |> insert!()

      assert_raise FunctionClauseError, fn ->
        Prices.update_price(price, %{active: false})
      end
    end
  end

  describe "delete_price/2" do
    test "with a valid price, soft delete the price" do
      price_factory = build(:price) |> make_type_one_time() |> insert!()
      utc_now = utc_now()

      assert {:ok, %Price{} = price} = Prices.delete_price(price_factory, utc_now)
      assert price.deleted_at == utc_now
    end

    test "when price is soft deleted, raises a FunctionClauseError" do
      price =
        build(:price)
        |> make_deleted()
        |> make_type_one_time()
        |> insert!()

      assert_raise FunctionClauseError, fn ->
        Prices.delete_price(price, utc_now())
      end
    end

    test "when deleted_at is before created_at, returns an ecto changeset error" do
      price = build(:price) |> make_type_one_time() |> insert!()

      assert {:error, changeset} = Prices.delete_price(price, price.created_at |> add(-1200))

      refute changeset.valid?
      assert %{deleted_at: ["should be after or equal to created_at"]} = errors_on(changeset)
    end
  end
end
