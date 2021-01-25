defmodule Tailcall.Billing.Products.ProductTest do
  use ExUnit.Case, async: true
  use Tailcall.DataCase

  alias Tailcall.Billing.Products.Product

  describe "create_changeset/2" do
    test "only permitted_keys are casted" do
      product_params =
        build(:product, metadata: %{key: "value"}) |> make_inactive() |> params_for()

      changeset =
        Product.create_changeset(%Product{}, Map.merge(product_params, %{new_key: "value"}))

      changes_keys = changeset.changes |> Map.keys()

      assert :account_id in changes_keys
      assert :active in changes_keys
      assert :caption in changes_keys
      assert :created_at in changes_keys
      assert :description in changes_keys
      assert :livemode in changes_keys
      assert :metadata in changes_keys
      assert :name in changes_keys
      assert :statement_descriptor in changes_keys
      assert :type in changes_keys
      assert :unit_label in changes_keys
      assert :url in changes_keys
      refute :deleted_at in changes_keys
      refute :new_key in changes_keys
    end

    test "when all params are valid, returns an valid changeset" do
      product_params = params_for(:product)

      changeset = Product.create_changeset(%Product{}, product_params)

      assert changeset.valid?
      assert get_field(changeset, :account_id) == product_params.account_id
      assert get_field(changeset, :active) == product_params.active
      assert get_field(changeset, :caption) == product_params.caption
      assert get_field(changeset, :created_at) == product_params.created_at
      assert get_field(changeset, :description) == product_params.description
      assert get_field(changeset, :livemode) == product_params.livemode
      assert get_field(changeset, :metadata) == product_params.metadata
      assert get_field(changeset, :name) == product_params.name
      assert get_field(changeset, :statement_descriptor) == product_params.statement_descriptor
      assert get_field(changeset, :type) == product_params.type
      assert get_field(changeset, :unit_label) == product_params.unit_label
      assert get_field(changeset, :url) == product_params.url
    end

    test "when required params are missing, returns an invalid changeset" do
      changeset = Product.create_changeset(%Product{}, %{active: nil})

      refute changeset.valid?
      assert length(changeset.errors) == 6
      assert %{account_id: ["can't be blank"]} = errors_on(changeset)
      assert %{active: ["can't be blank"]} = errors_on(changeset)
      assert %{created_at: ["can't be blank"]} = errors_on(changeset)
      assert %{livemode: ["can't be blank"]} = errors_on(changeset)
      assert %{name: ["can't be blank"]} = errors_on(changeset)
      assert %{type: ["can't be blank"]} = errors_on(changeset)
    end

    test "when params are invalid, returns an invalid changeset" do
      product_params = params_for(:product, type: "type")

      changeset = Product.create_changeset(%Product{}, product_params)

      refute changeset.valid?
      assert %{type: ["is invalid"]} = errors_on(changeset)
    end
  end

  describe "updade_changeset/2" do
    test "only permitted_keys are casted" do
      product = insert!(:product)

      product_params =
        build(:product, metadata: %{new_key: "value"}) |> make_inactive() |> params_for()

      changeset =
        Product.update_changeset(product, Map.merge(product_params, %{new_key: "value"}))

      changes_keys = changeset.changes |> Map.keys()

      refute :account_id in changes_keys
      assert :active in changes_keys
      assert :caption in changes_keys
      refute :created_at in changes_keys
      assert :description in changes_keys
      refute :livemode in changes_keys
      assert :metadata in changes_keys
      assert :name in changes_keys
      assert :statement_descriptor in changes_keys
      refute :type in changes_keys
      assert :unit_label in changes_keys
      assert :url in changes_keys
      refute :deleted_at in changes_keys
      refute :new_key in changes_keys
    end

    test "when all params are valid, returns an valid changeset" do
      product = insert!(:product)

      product_params = build(:product) |> make_inactive() |> params_for()

      changeset = Product.update_changeset(product, product_params)

      assert changeset.valid?
      assert get_field(changeset, :active) == product_params.active
    end

    test "when required params are missing, returns an invalid changeset" do
      product = insert!(:product, active: true)

      changeset = Product.update_changeset(product, %{active: nil, name: nil})

      refute changeset.valid?
      assert length(changeset.errors) == 2
      assert %{active: ["can't be blank"]} = errors_on(changeset)
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "delete_changeset/2" do
    test "when deleted_at is valid, returns an valid changeset" do
      product = insert!(:product)

      utc_now = utc_now()

      changeset = Product.delete_changeset(product, %{deleted_at: utc_now})

      assert changeset.valid?
      assert get_field(changeset, :deleted_at) == utc_now
    end

    test "when deleted_at is nil, returns an invalid changeset" do
      product = insert!(:product)

      changeset = Product.delete_changeset(product, %{})

      refute changeset.valid?
      assert %{deleted_at: ["can't be blank"]} = errors_on(changeset)
    end

    test "when deleted_at is before created_at, returns an invalid changeset" do
      product = insert!(:product, created_at: utc_now())

      changeset = Product.delete_changeset(product, %{deleted_at: utc_now() |> add(-1200)})

      refute changeset.valid?

      assert %{deleted_at: ["should be after or equal to created_at"]} = errors_on(changeset)
    end
  end
end
