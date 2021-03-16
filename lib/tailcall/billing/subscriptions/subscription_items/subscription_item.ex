defmodule Tailcall.Billing.Subscriptions.SubscriptionItems.SubscriptionItem do
  use Ecto.Schema

  import Ecto.Changeset,
    only: [
      add_error: 3,
      assoc_constraint: 2,
      cast: 3,
      get_field: 2,
      get_change: 2,
      put_change: 3,
      validate_number: 3,
      validate_required: 2
    ]

  alias Tailcall.Billing.Prices
  alias Tailcall.Billing.Prices.Price
  alias Tailcall.Billing.Subscriptions
  alias Tailcall.Billing.Subscriptions.Subscription

  @type t :: %__MODULE__{
          created_at: DateTime.t(),
          deleted_at: DateTime.t() | nil,
          id: binary,
          inserted_at: DateTime.t(),
          is_prepaid: boolean,
          metadata: map,
          object: binary,
          price: Price.t(),
          price_id: binary,
          quantity: integer | nil,
          subscription: Subscription.t(),
          subscription_id: binary,
          updated_at: DateTime.t()
        }

  @primary_key {:id, Shortcode.Ecto.ID, prefix: "si", autogenerate: true}
  schema "subscription_items" do
    field(:object, :string, default: "subscription_item")
    field(:account_id, :string, virtual: true)
    belongs_to(:subscription, Subscription, type: Shortcode.Ecto.ID, prefix: "sub")

    field(:created_at, :utc_datetime)
    field(:is_prepaid, :boolean, default: true)
    field(:livemode, :boolean, virtual: true)
    field(:metadata, :map, default: %{})
    belongs_to(:price, Price, type: Shortcode.Ecto.ID, prefix: "price")
    field(:proration_date, :utc_datetime, virtual: true)
    field(:quantity, :integer)

    field(:deleted_at, :utc_datetime)
    timestamps(type: :utc_datetime)
  end

  @spec nested_create_changeset(SubscriptionItem.t(), map()) :: Ecto.Changeset.t()
  def nested_create_changeset(%__MODULE__{} = subscription_item, attrs) when is_map(attrs) do
    subscription_item
    |> cast(attrs, [
      :account_id,
      :created_at,
      :is_prepaid,
      :livemode,
      :metadata,
      :price_id,
      :quantity
    ])
    |> maybe_put_created_at()
    |> validate_required([:account_id, :created_at, :livemode, :price_id])
    |> validate_number(:quantity, greater_than_or_equal_to: 0)
    |> assoc_constraint(:price)
    |> maybe_preload_price()
    |> validate_price_is_recurring_type()
  end

  @spec create_changeset(SubscriptionItem.t(), map()) :: Ecto.Changeset.t()
  def create_changeset(%__MODULE__{} = subscription_item, attrs) when is_map(attrs) do
    subscription_item
    |> cast(attrs, [
      :created_at,
      :is_prepaid,
      :metadata,
      :price_id,
      :quantity
    ])
    |> maybe_put_created_at()
    |> put_change_account_id()
    |> put_change_livemode()
    |> put_change_subscription_id()
    |> validate_required([:created_at, :price_id, :subscription_id])
    |> validate_number(:quantity, greater_than_or_equal_to: 0)
    |> assoc_constraint(:subscription)
    |> validate_price()
    |> maybe_put_quantity()
    |> validate_proration_date_is_in_the_subscription_current_period_range()
  end

  @spec update_changeset(SubscriptionItem.t(), map()) :: Ecto.Changeset.t()
  def update_changeset(%__MODULE__{} = subscription_item, attrs) when is_map(attrs) do
    subscription_item
    |> cast(attrs, [:metadata, :price_id, :quantity])
    |> put_change_account_id()
    |> put_change_livemode()
    |> validate_required([:price_id])
    |> validate_number(:quantity, greater_than_or_equal_to: 0)
    |> validate_price()
    |> validate_proration_date_is_in_the_subscription_current_period_range()
  end

  @spec delete_changeset(SubscriptionItem.t(), map()) :: Ecto.Changeset.t()
  def delete_changeset(%__MODULE__{} = subscription_item, attrs) when is_map(attrs) do
    subscription_item
    |> cast(attrs, [:deleted_at])
    |> validate_required([:deleted_at])
    |> AntlUtilsEcto.Changeset.validate_datetime_gte(:deleted_at, :created_at)
    |> validate_ongoing_subscription_items_length()
  end

  defp validate_proration_date_is_in_the_subscription_current_period_range(
         %Ecto.Changeset{valid?: false} = changeset
       ),
       do: changeset

  defp validate_proration_date_is_in_the_subscription_current_period_range(
         %Ecto.Changeset{} = changeset
       ) do
    subscription = get_field(changeset, :subscription)

    changeset
    |> AntlUtilsEcto.Changeset.validate_datetime_gte(
      :proration_date,
      subscription.current_period_start
    )
    |> AntlUtilsEcto.Changeset.validate_datetime_lte(
      :proration_date,
      subscription.current_period_end
    )
  end

  defp maybe_put_created_at(%Ecto.Changeset{} = changeset) do
    created_at = get_field(changeset, :created_at)

    if created_at do
      changeset
    else
      changeset |> put_change(:created_at, DateTime.utc_now() |> DateTime.truncate(:second))
    end
  end

  defp put_change_account_id(%Ecto.Changeset{} = changeset) do
    subscription = get_field(changeset, :subscription)
    changeset |> put_change(:account_id, subscription.account_id)
  end

  defp put_change_subscription_id(%Ecto.Changeset{} = changeset) do
    subscription = get_field(changeset, :subscription)
    changeset |> put_change(:subscription_id, subscription.id)
  end

  defp put_change_livemode(%Ecto.Changeset{} = changeset) do
    subscription = get_field(changeset, :subscription)
    changeset |> put_change(:livemode, subscription.livemode)
  end

  defp validate_price(%Ecto.Changeset{} = changeset) do
    changeset
    |> assoc_constraint(:price)
    |> maybe_preload_price()
    |> validate_price_is_recurring_type()
    |> validate_price_currency()
    |> validate_price_recurring_interval_fields()
    |> validate_price_is_uniq_among_subscription_items()
  end

  defp maybe_preload_price(%Ecto.Changeset{valid?: false} = changeset),
    do: changeset

  defp maybe_preload_price(%Ecto.Changeset{} = changeset) do
    account_id = get_field(changeset, :account_id)
    price_id = get_field(changeset, :price_id)
    livemode = get_field(changeset, :livemode)

    price =
      Prices.get_price(price_id,
        filters: [account_id: account_id, livemode: livemode],
        includes: [:product]
      )

    if price do
      %{changeset | data: %{changeset.data | price: price}}
    else
      changeset |> Ecto.Changeset.add_error(:price_id, "does not exist")
    end
  end

  defp validate_price_is_recurring_type(%Ecto.Changeset{valid?: false} = changeset),
    do: changeset

  defp validate_price_is_recurring_type(%Ecto.Changeset{} = changeset) do
    price = get_field(changeset, :price)

    if is_map(price) and price.type == Price.types().recurring do
      changeset
    else
      changeset |> Ecto.Changeset.add_error(:price_id, "accepts only prices with recurring type")
    end
  end

  defp validate_price_currency(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp validate_price_currency(%Ecto.Changeset{} = changeset) do
    subscription = get_field(changeset, :subscription)

    expected_currency = Subscriptions.currency(subscription)
    %{currency: currency} = get_field(changeset, :price)

    if currency == expected_currency do
      changeset
    else
      changeset
      |> add_error(:price_id, "price must match the currency `#{expected_currency}`")
    end
  end

  defp validate_price_recurring_interval_fields(%Ecto.Changeset{valid?: false} = changeset),
    do: changeset

  defp validate_price_recurring_interval_fields(%Ecto.Changeset{} = changeset) do
    subscription = get_field(changeset, :subscription)

    %{
      recurring_interval: expected_recurring_interval,
      recurring_interval_count: expected_recurring_interval_count
    } = Subscriptions.recurring_interval_fields(subscription)

    %{recurring_interval: recurring_interval, recurring_interval_count: recurring_interval_count} =
      get_field(changeset, :price)

    if recurring_interval == expected_recurring_interval and
         recurring_interval_count == expected_recurring_interval_count do
      changeset
    else
      changeset
      |> add_error(
        :price_id,
        "price must match the recurring_interval `#{expected_recurring_interval}` and the recurring_interval_count `#{
          expected_recurring_interval_count
        }`"
      )
    end
  end

  defp validate_price_is_uniq_among_subscription_items(
         %Ecto.Changeset{valid?: false} = changeset
       ),
       do: changeset

  defp validate_price_is_uniq_among_subscription_items(%Ecto.Changeset{} = changeset) do
    subscription = get_field(changeset, :subscription)

    price_ids = subscription.items |> Enum.map(& &1.price_id)
    price_id = get_change(changeset, :price_id)

    if not is_nil(price_id) and price_id in price_ids do
      changeset |> add_error(:price_id, "has already been taken")
    else
      changeset
    end
  end

  defp validate_ongoing_subscription_items_length(%Ecto.Changeset{valid?: false} = changeset),
    do: changeset

  defp validate_ongoing_subscription_items_length(%Ecto.Changeset{} = changeset) do
    subscription = get_field(changeset, :subscription)
    id = get_field(changeset, :id)

    ongoing_items = subscription.items |> Enum.reject(&(&1.id == id))

    if length(ongoing_items) > 0 do
      changeset
    else
      changeset |> add_error(:deleted_at, "subscription must have at least one active price")
    end
  end

  defp maybe_put_quantity(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp maybe_put_quantity(%Ecto.Changeset{} = changeset) do
    price = get_field(changeset, :price)
    quantity = get_field(changeset, :quantity)

    if is_nil(quantity) and price.recurring_usage_type == Price.recurring_usage_types().licensed do
      changeset |> put_change(:quantity, 1)
    else
      changeset
    end
  end
end
