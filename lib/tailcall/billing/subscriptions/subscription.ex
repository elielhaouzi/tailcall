defmodule Tailcall.Billing.Subscriptions.Subscription do
  use Ecto.Schema

  import Ecto.Changeset,
    only: [
      cast: 3,
      cast_assoc: 3,
      validate_inclusion: 3,
      validate_required: 2
    ]

  alias Tailcall.Accounts.Account
  alias Tailcall.Core.Customers.Customer

  alias Tailcall.Billing.Invoices.Invoice
  alias Tailcall.Billing.Subscriptions.SubscriptionItem

  @type t :: %__MODULE__{
          account: Account.t(),
          account_id: binary,
          created_at: DateTime.t(),
          customer: Customer.t(),
          customer_id: binary,
          current_period_end: DateTime.t(),
          current_period_start: DateTime.t(),
          ended_at: DateTime.t() | nil,
          id: binary,
          inserted_at: DateTime.t(),
          items: [SubscriptionItem.t()],
          latest_invoice: Invoice.t() | nil,
          latest_invoice_id: binary | nil,
          livemode: boolean,
          object: binary,
          started_at: DateTime.t(),
          status: binary,
          updated_at: DateTime.t()
        }

  @primary_key {:id, Shortcode.Ecto.ID, prefix: "sub", autogenerate: true}
  schema "subscriptions" do
    field(:object, :string, default: "subscription")

    belongs_to(:account, Account, type: Shortcode.Ecto.ID, prefix: "acct")
    belongs_to(:customer, Customer, type: Shortcode.Ecto.ID, prefix: "cus")

    field(:cancel_at, :utc_datetime)
    field(:cancel_at_period_end, :boolean, default: false)
    field(:cancellation_reason, :string)
    field(:canceled_at, :utc_datetime)
    field(:created_at, :utc_datetime)
    field(:current_period_end, :utc_datetime)
    field(:current_period_start, :utc_datetime)
    field(:collection_method, :string, default: "charge_automatically")
    field(:ended_at, :utc_datetime)
    has_many(:items, SubscriptionItem)
    field(:last_period_end, :utc_datetime, virtual: true)
    field(:last_period_start, :utc_datetime, virtual: true)
    has_one(:latest_invoice, Invoice)
    field(:latest_invoice_id, :string, virtual: true)
    field(:livemode, :boolean)
    field(:next_period_end, :utc_datetime, virtual: true)
    field(:next_period_start, :utc_datetime, virtual: true)
    field(:oban_job_id, :integer, virtual: true)
    field(:started_at, :utc_datetime)
    field(:status, :string)

    timestamps(type: :utc_datetime)
  end

  @spec collection_methods :: %{charge_automatically: binary, send_invoice: binary}
  def collection_methods,
    do: %{charge_automatically: "charge_automatically", send_invoice: "send_invoice"}

  def cancellation_reasons, do: %{requested_by_customer: "requested_by_customer"}

  @spec statuses :: %{
          active: binary(),
          past_due: binary(),
          unpaid: binary(),
          canceled: binary(),
          incomplete: binary(),
          incomplete_expired: binary(),
          trialing: binary()
        }
  def statuses,
    do: %{
      active: "active",
      past_due: "past_due",
      unpaid: "unpaid",
      canceled: "canceled",
      incomplete: "incomplete",
      incomplete_expired: "incomplete_expired",
      trialing: "trialing"
    }

  @spec create_changeset(Subscription.t(), map()) :: Ecto.Changeset.t()
  def create_changeset(%__MODULE__{} = subscription, attrs) when is_map(attrs) do
    attrs =
      attrs
      |> AntlUtilsElixir.Map.populate_child(:created_at, :items)
      |> AntlUtilsElixir.Map.populate_child(:started_at, :items)

    # attrs =
    #   attrs
    #   |> Map.put_new(:billing_cycle_anchor, started_at)

    subscription
    |> cast(attrs, [
      :account_id,
      :customer_id,
      :created_at,
      :current_period_end,
      :current_period_start,
      :collection_method,
      :livemode,
      :started_at
    ])
    |> validate_required([
      :account_id,
      :customer_id,
      :collection_method,
      :created_at,
      :livemode,
      :started_at
    ])
    |> cast_assoc(:items, required: true, with: &SubscriptionItem.nested_create_changeset/2)

    # |> validate_subscription_items_constaints()
  end

  @spec update_changeset(Subscription.t(), map()) :: Ecto.Changeset.t()
  def update_changeset(%__MODULE__{} = subscription, attrs) when is_map(attrs) do
    subscription
    |> cast(attrs, [:current_period_end, :current_period_start, :status])
    |> AntlUtilsEcto.Changeset.validate_datetime_gte(
      :current_period_end,
      :current_period_start
    )
    |> validate_inclusion(:status, Map.values(statuses()))
  end

  @spec cancel_changeset(Subscription.t(), map()) :: Ecto.Changeset.t()
  def cancel_changeset(%__MODULE__{} = subscription, attrs) when is_map(attrs) do
    subscription
    |> cast(attrs, [:cancel_at, :cancel_at_period_end, :cancellation_reason, :canceled_at])
    |> validate_required([:cancel_at, :cancellation_reason, :canceled_at])
    |> AntlUtilsEcto.Changeset.validate_datetime_gte(:cancel_at, :started_at)
  end
end
