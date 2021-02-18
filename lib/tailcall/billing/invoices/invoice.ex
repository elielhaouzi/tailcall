defmodule Tailcall.Billing.Invoices.Invoice do
  use Ecto.Schema

  import Ecto.Changeset,
    only: [
      assoc_constraint: 2,
      cast: 3,
      cast_assoc: 3,
      get_field: 2,
      put_change: 3,
      validate_inclusion: 3,
      validate_number: 3,
      validate_required: 2
    ]

  alias Tailcall.Accounts.Account
  alias Tailcall.Core.Customers.Customer
  alias Tailcall.Billing.Subscriptions.Subscription
  alias Tailcall.Billing.Invoices.InvoiceLineItem

  @day_in_seconds 24 * 3600

  @type t :: %__MODULE__{
          account: Account.t(),
          account_id: binary,
          account_name: binary,
          amount_due: integer,
          amount_paid: integer,
          amount_remaining: integer,
          auto_advance: boolean,
          created_at: DateTime.t(),
          customer: Customer.t(),
          customer_id: binary,
          currency: binary,
          deleted_at: DateTime.t() | nil,
          livemode: boolean,
          number: binary,
          period_end: DateTime.t(),
          period_start: DateTime.t(),
          id: binary,
          inserted_at: DateTime.t(),
          object: binary,
          status: binary,
          total: integer,
          updated_at: DateTime.t()
        }

  # @proration_behaviors ["create_prorations", "none"]

  @primary_key {:id, Shortcode.Ecto.ID, prefix: "in", autogenerate: true}
  schema "invoices" do
    field(:object, :string, default: "invoice")

    belongs_to(:account, Account, type: Shortcode.Ecto.ID, prefix: "acct")
    belongs_to(:customer, Customer, type: Shortcode.Ecto.ID, prefix: "cus")
    belongs_to(:subscription, Subscription, type: Shortcode.Ecto.ID, prefix: "sub")

    field(:account_name, :string)
    field(:amount_due, :integer)
    field(:amount_paid, :integer)
    field(:amount_remaining, :integer)
    field(:auto_advance, :boolean, default: true)
    field(:billing_reason, :string)
    field(:collection_method, :string, default: "charge_automatically")
    field(:created_at, :utc_datetime)
    field(:currency, :string)
    field(:customer_email, :string)
    field(:customer_name, :string)
    field(:days_until_due, :integer, virtual: true)
    field(:due_date, :utc_datetime)
    field(:livemode, :boolean)
    has_many(:line_items, InvoiceLineItem)
    field(:number, :string)
    field(:period_end, :utc_datetime)
    field(:period_start, :utc_datetime)
    field(:status, :string)
    field(:total, :integer)

    field(:deleted_at, :utc_datetime)
    timestamps(type: :utc_datetime)
  end

  @spec billing_reasons :: %{
          manual: binary,
          subscription_create: binary,
          subscription_cycle: binary,
          subscription_update: binary,
          subscription_threshold: binary,
          upcoming: binary
        }
  def billing_reasons,
    do: %{
      manual: "manual",
      subscription_create: "subscription_create",
      subscription_cycle: "subscription_cycle",
      subscription_update: "subscription_update",
      subscription_threshold: "subscription_threshold",
      upcoming: "upcoming"
    }

  @spec collection_methods :: %{charge_automatically: binary, send_invoice: binary}
  def collection_methods,
    do: %{charge_automatically: "charge_automatically", send_invoice: "send_invoice"}

  @spec statuses :: %{
          draft: binary,
          open: binary,
          paid: binary,
          uncollectible: binary,
          void: binary
        }
  def statuses,
    do: %{
      draft: "draft",
      open: "open",
      paid: "paid",
      uncollectible: "uncollectible",
      void: "void"
    }

  @spec create_changeset(Invoice.t(), map) :: Ecto.Changeset.t()
  def create_changeset(%__MODULE__{} = invoice, attrs) when is_map(attrs) do
    attrs =
      attrs
      |> AntlUtilsElixir.Map.populate_child(:created_at, :line_items)
      |> AntlUtilsElixir.Map.populate_child(:currency, :line_items)
      |> AntlUtilsElixir.Map.populate_child(:livemode, :line_items)
      |> AntlUtilsElixir.Map.populate_child(:subscription_id, :line_items)

    invoice
    |> cast(attrs, [
      :account_id,
      :customer_id,
      :subscription_id,
      :account_name,
      :amount_due,
      :amount_paid,
      :amount_remaining,
      :auto_advance,
      :billing_reason,
      :collection_method,
      :created_at,
      :customer_email,
      :customer_name,
      :currency,
      :days_until_due,
      :due_date,
      :livemode,
      :period_end,
      :period_start,
      :status,
      :total
    ])
    |> validate_required([
      :account_id,
      :customer_id,
      :amount_due,
      :amount_paid,
      :amount_remaining,
      :billing_reason,
      :collection_method,
      :created_at,
      :currency,
      :livemode,
      :period_end,
      :period_start,
      :status,
      :total
    ])
    |> AntlUtilsEcto.Changeset.validate_datetime_gte(:period_end, :period_start)
    |> validate_inclusion(:billing_reason, Map.values(billing_reasons()))
    |> validate_inclusion(:collection_method, Map.values(collection_methods()))
    |> validate_due_date_according_to_collection_method()
    |> validate_inclusion(:status, Map.values(statuses()))
    |> cast_assoc(:line_items, required: true, with: &InvoiceLineItem.nested_create_changeset/2)
    |> assoc_constraint(:subscription)
  end

  defp validate_due_date_according_to_collection_method(
         %Ecto.Changeset{valid?: false} = changeset
       ),
       do: changeset

  defp validate_due_date_according_to_collection_method(%Ecto.Changeset{} = changeset) do
    %{charge_automatically: charge_automatically, send_invoice: send_invoice} =
      collection_methods()

    changeset
    |> get_field(:collection_method)
    |> case do
      ^charge_automatically ->
        changeset
        |> AntlUtilsEcto.Changeset.validate_empty([:days_until_due, :due_date])

      ^send_invoice ->
        changeset
        |> validate_number(:days_until_due, greater_than_or_equal_to: 0)
        |> AntlUtilsEcto.Changeset.validate_empty_with(:due_date, :days_until_due)
        |> AntlUtilsEcto.Changeset.validate_empty_with(:days_until_due, :due_date)
        |> maybe_put_due_date_according_to_days_until_due()
        |> AntlUtilsEcto.Changeset.validate_datetime_gte(:due_date, :created_at)
    end
  end

  defp maybe_put_due_date_according_to_days_until_due(%Ecto.Changeset{valid?: false} = changeset),
    do: changeset

  defp maybe_put_due_date_according_to_days_until_due(%Ecto.Changeset{} = changeset) do
    created_at = get_field(changeset, :created_at)
    days_until_due = get_field(changeset, :days_until_due)

    if days_until_due do
      changeset
      |> put_change(:due_date, DateTime.add(created_at, days_until_due * @day_in_seconds))
    else
      changeset
    end
  end
end
