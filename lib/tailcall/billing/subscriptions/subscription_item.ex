defmodule Tailcall.Billing.Subscriptions.SubscriptionItem do
  use Ecto.Schema

  import Ecto.Changeset,
    only: [assoc_constraint: 2, cast: 3, validate_number: 3, validate_required: 2]

  alias Tailcall.Billing.Prices.Price

  alias Tailcall.Billing.Subscriptions.Subscription

  @type t :: %__MODULE__{
          created_at: DateTime.t(),
          ended_at: DateTime.t() | nil,
          id: binary,
          inserted_at: DateTime.t(),
          object: binary,
          price: Price.t(),
          price_id: binary,
          quantity: integer | nil,
          started_at: DateTime.t(),
          subscription: Subscription.t(),
          subscription_id: binary,
          updated_at: DateTime.t()
        }

  @primary_key {:id, Shortcode.Ecto.ID, prefix: "si", autogenerate: true}
  schema "subscription_items" do
    field(:object, :string, default: "subscription_item")

    belongs_to(:subscription, Subscription, type: Shortcode.Ecto.ID, prefix: "sub")

    field(:created_at, :utc_datetime)
    field(:ended_at, :utc_datetime)
    belongs_to(:price, Price, type: Shortcode.Ecto.ID, prefix: "price")
    field(:quantity, :integer)
    field(:started_at, :utc_datetime)

    timestamps(type: :utc_datetime)
  end

  @spec nested_create_changeset(SubscriptionItem.t(), map()) :: Ecto.Changeset.t()
  def nested_create_changeset(%__MODULE__{} = subscription_item, attrs) when is_map(attrs) do
    subscription_item
    |> cast(attrs, [:created_at, :price_id, :quantity, :started_at])
    |> validate_required([:created_at, :price_id, :started_at])
    |> validate_number(:quantity, greater_than_or_equal_to: 0)
    |> assoc_constraint(:price)
  end
end
