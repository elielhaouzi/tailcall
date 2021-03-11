defmodule Tailcall.Billing.Subscriptions.SubscriptionItem do
  use Ecto.Schema

  import Ecto.Changeset,
    only: [assoc_constraint: 2, cast: 3, get_field: 2, validate_number: 3, validate_required: 2]

  alias Tailcall.Billing.Prices
  alias Tailcall.Billing.Prices.Price

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
    |> validate_required([:account_id, :created_at, :livemode, :price_id])
    |> validate_number(:quantity, greater_than_or_equal_to: 0)
    |> assoc_constraint(:price)
    |> maybe_preload_price()
    |> validate_price_is_recurring_type()
  end

  @spec nested_update_changeset(SubscriptionItem.t(), map()) :: Ecto.Changeset.t()
  def nested_update_changeset(%__MODULE__{} = subscription_item, attrs) when is_map(attrs) do
    subscription_item
    |> cast(attrs, [:account_id, :livemode, :price_id, :quantity, :deleted_at])
    |> validate_required([:livemode, :price_id])
    |> validate_number(:quantity, greater_than_or_equal_to: 0)
    |> AntlUtilsEcto.Changeset.validate_datetime_gte(:deleted_at, :created_at)
    |> assoc_constraint(:price)
    |> maybe_preload_price()
    |> validate_price_is_recurring_type()
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
end
