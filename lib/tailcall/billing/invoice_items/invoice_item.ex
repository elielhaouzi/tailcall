defmodule Tailcall.Billing.InvoiceItems.InvoiceItem do
  use Ecto.Schema

  import Ecto.Changeset, only: [assoc_constraint: 2, cast: 3, validate_required: 2]

  alias Tailcall.Accounts.Account
  alias Tailcall.Core.Customers.Customer
  alias Tailcall.Billing.Prices.Price
  alias Tailcall.Billing.Subscriptions.Subscription
  alias Tailcall.Billing.Subscriptions.SubscriptionItems.SubscriptionItem
  alias Tailcall.Billing.Invoices.Invoice

  @type t :: %__MODULE__{
          account: Account.t() | nil,
          account_id: binary,
          amount: integer,
          created_at: DateTime.t(),
          currency: binary,
          customer: Customer.t() | nil,
          customer_id: binary,
          description: binary,
          # discounts: []
          id: binary,
          inserted_at: DateTime.t(),
          invoice: Invoice.t() | nil,
          invoice_id: binary | nil,
          is_discountable: boolean,
          is_proration: boolean,
          metadata: map,
          object: binary,
          period_end: DateTime.t(),
          period_start: DateTime.t(),
          price: Price.t() | nil,
          price_id: binary,
          quantity: integer,
          unit_amount: integer,
          unit_amount_decimal: Decimal.t(),
          updated_at: DateTime.t()
        }

  @primary_key {:id, Shortcode.Ecto.ID, prefix: "ii", autogenerate: true}
  schema "invoice_items" do
    field(:object, :string, default: "invoiceitem")

    belongs_to(:account, Account, type: Shortcode.Ecto.ID, prefix: "acct")
    belongs_to(:customer, Customer, type: Shortcode.Ecto.ID, prefix: "cus")
    belongs_to(:price, Price, type: Shortcode.Ecto.ID, prefix: "price")
    belongs_to(:invoice, Invoice, type: Shortcode.Ecto.ID, prefix: "in")
    belongs_to(:subscription, Subscription, type: Shortcode.Ecto.ID, prefix: "sub")
    belongs_to(:subscription_item, SubscriptionItem, type: Shortcode.Ecto.ID, prefix: "si")

    field(:amount, :integer)
    field(:created_at, :utc_datetime)
    field(:currency, :string)
    field(:description, :string)
    field(:is_discountable, :boolean)
    field(:is_proration, :boolean)
    field(:livemode, :boolean)
    field(:metadata, :map, default: %{})
    field(:period_end, :utc_datetime)
    field(:period_start, :utc_datetime)

    field(:quantity, :integer)
    field(:unit_amount, :integer)
    field(:unit_amount_decimal, :decimal)

    field(:deleted_at, :utc_datetime)
    timestamps(type: :utc_datetime)
  end

  @spec create_changeset(InvoiceItem.t(), map) :: Ecto.Changeset.t()
  def create_changeset(%__MODULE__{} = invoice_item, attrs) when is_map(attrs) do
    invoice_item
    |> cast(attrs, [
      :account_id,
      :customer_id,
      :subscription_id,
      :subscription_item_id,
      :price_id,
      :invoice_id,
      :amount,
      :created_at,
      :description,
      :discountable,
      :livemode,
      :metadata,
      :period_end,
      :period_start,
      :is_proration,
      :quantity
    ])
    |> validate_required([
      :account_id,
      :customer_id,
      :price_id,
      :amount,
      :created_at,
      :description,
      :discountable,
      :livemode,
      :metadata,
      :period_end,
      :period_start,
      :is_proration,
      :quantity
    ])
    |> AntlUtilsEcto.Changeset.validate_datetime_gte(:period_end, :period_start)
    |> assoc_constraint(:subscription)
    |> assoc_constraint(:subscription_item)
    |> assoc_constraint(:price)
    |> assoc_constraint(:invoice)
  end

  @spec update_changeset(InvoiceItem.t(), map()) :: Ecto.Changeset.t()
  def update_changeset(%__MODULE__{} = invoice_item, attrs) when is_map(attrs) do
    invoice_item
    |> cast(attrs, [:description])
  end
end
