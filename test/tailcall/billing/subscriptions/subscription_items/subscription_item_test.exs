defmodule Tailcall.Billing.Subscriptions.SubscriptionItems.SubscriptionItemTest do
  use ExUnit.Case, async: true
  use Tailcall.DataCase

  alias Tailcall.Billing.Subscriptions.SubscriptionItems.SubscriptionItem

  @moduletag :subscriptions

  describe "nested_create_changeset/2" do
    test "only permitted_keys are casted" do
      subscription_item_params =
        params_for(:subscription_item, account_id: "account_id", metadata: %{key: "value"})

      changeset =
        SubscriptionItem.nested_create_changeset(
          %SubscriptionItem{},
          Map.merge(subscription_item_params, %{new_key: "value"})
        )

      changes_keys = changeset.changes |> Map.keys()

      assert :account_id in changes_keys
      refute :subscription_id in changes_keys
      assert :created_at in changes_keys
      assert :metadata in changes_keys
      assert :price_id in changes_keys
      assert :quantity in changes_keys
      refute :deleted_at in changes_keys
      refute :new_key in changes_keys
    end

    test "when all params are valid, returns an valid changeset" do
      subscription_item_params = params_for(:subscription_item, account_id: "account_id")

      changeset =
        SubscriptionItem.nested_create_changeset(%SubscriptionItem{}, subscription_item_params)

      assert changeset.valid?
      assert get_field(changeset, :account_id) == subscription_item_params.account_id
      assert get_field(changeset, :created_at) == subscription_item_params.created_at
      assert get_field(changeset, :metadata) == subscription_item_params.metadata
      assert get_field(changeset, :price_id) == subscription_item_params.price_id
      assert get_field(changeset, :quantity) == subscription_item_params.quantity
    end

    test "when required params are missing, returns an invalid changeset" do
      changeset = SubscriptionItem.nested_create_changeset(%SubscriptionItem{}, %{})

      refute changeset.valid?
      assert length(changeset.errors) == 3
      assert %{account_id: ["can't be blank"]} = errors_on(changeset)
      assert %{livemode: ["can't be blank"]} = errors_on(changeset)
      assert %{price_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "when params are invalid, returns an invalid changeset" do
      subscription_item_params = params_for(:subscription_item, quantity: -1)

      changeset =
        SubscriptionItem.nested_create_changeset(%SubscriptionItem{}, subscription_item_params)

      refute changeset.valid?
      assert %{quantity: ["must be greater than or equal to 0"]} = errors_on(changeset)
    end

    test "when price does not exists, returns an invalid changeset" do
      subscription_item_params =
        params_for(:subscription_item, account_id: "account_id", price_id: shortcode_id())

      changeset =
        SubscriptionItem.nested_create_changeset(%SubscriptionItem{}, subscription_item_params)

      refute changeset.valid?
      assert %{price_id: ["does not exist"]} = errors_on(changeset)
    end

    test "when price belongs to an another account_id, returns an invalid changeset" do
      price = insert!(:price)

      subscription_item_params =
        params_for(:subscription_item, account_id: "account_id", price_id: price.id)

      changeset =
        SubscriptionItem.nested_create_changeset(%SubscriptionItem{}, subscription_item_params)

      refute changeset.valid?
      assert %{price_id: ["does not exist"]} = errors_on(changeset)
    end

    test "when price is a one_time type, returns an invalid changeset" do
      price = build(:price) |> make_type_one_time() |> insert!()

      subscription_item_params =
        params_for(:subscription_item, account_id: price.account_id, price_id: price.id)

      changeset =
        SubscriptionItem.nested_create_changeset(%SubscriptionItem{}, subscription_item_params)

      refute changeset.valid?
      assert %{price_id: ["accepts only prices with recurring type"]} = errors_on(changeset)
    end
  end
end
