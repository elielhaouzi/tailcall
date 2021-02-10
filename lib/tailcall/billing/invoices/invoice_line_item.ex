defmodule Tailcall.Billing.Invoices.InvoiceLineItem do
  use Ecto.Schema

  import Ecto.Changeset,
    only: [
      assoc_constraint: 2,
      cast: 3,
      validate_inclusion: 3,
      validate_required: 2
    ]

  alias Tailcall.Billing.Prices.Price
  alias Tailcall.Billing.Subscriptions.{Subscription, SubscriptionItem}
  alias Tailcall.Billing.Invoices.Invoice

  # @type t :: %__MODULE__{
  #         account: Account.t(),
  #         account_id: binary,
  #         created_at: DateTime.t(),
  #         customer: Customer.t(),
  #         customer_id: binary,
  #         currency: binary,
  #         deleted_at: DateTime.t() | nil,
  #         livemode: boolean,
  #         period_end: DateTime.t(),
  #         period_start: DateTime.t(),
  #         id: binary,
  #         inserted_at: DateTime.t(),
  #         object: binary,
  #         status: binary,
  #         total: integer,
  #         updated_at: DateTime.t()
  #       }

  @primary_key {:id, Shortcode.Ecto.ID, prefix: "ili", autogenerate: true}
  schema "invoice_line_items" do
    field(:object, :string, default: "invoice_line_item")

    belongs_to(:invoice, Invoice, type: Shortcode.Ecto.ID, prefix: "in")
    belongs_to(:price, Price, type: Shortcode.Ecto.ID, prefix: "price")
    belongs_to(:subscription, Subscription, type: Shortcode.Ecto.ID, prefix: "sub")
    belongs_to(:subscription_item, SubscriptionItem, type: Shortcode.Ecto.ID, prefix: "si")

    field(:amount, :integer)
    field(:created_at, :utc_datetime)
    field(:currency, :string)
    field(:livemode, :boolean)
    field(:period_end, :utc_datetime)
    field(:period_start, :utc_datetime)
    field(:quantity, :integer)
    field(:type, :string)

    timestamps(type: :utc_datetime)
  end

  @spec types :: %{invoiceitem: binary, subscription: binary}
  def types, do: %{invoiceitem: "invoiceitem", subscription: "subscription"}

  @spec nested_create_changeset(InvoiceLineItem.t(), map) :: Ecto.Changeset.t()
  def nested_create_changeset(%__MODULE__{} = invoice_line_item, attrs) when is_map(attrs) do
    invoice_line_item
    |> cast(attrs, [
      :price_id,
      :subscription_id,
      :subscription_item_id,
      :amount,
      :created_at,
      :currency,
      :livemode,
      :period_end,
      :period_start,
      :quantity,
      :type
    ])
    |> validate_required([
      :price_id,
      :amount,
      :created_at,
      :currency,
      :livemode,
      :period_end,
      :period_start,
      :quantity,
      :type
    ])
    |> AntlUtilsEcto.Changeset.validate_datetime_gte(:period_end, :period_start)
    |> validate_inclusion(:type, Map.values(types()))
    |> assoc_constraint(:invoice)
    |> assoc_constraint(:price)
    |> assoc_constraint(:subscription)
    |> assoc_constraint(:subscription_item)
  end
end
