defmodule Tailcall.Billing.InvoiceItems do
  @moduledoc """
  The Invoices context.
  """

  import Ecto.Query, only: [order_by: 2]

  alias Ecto.Multi
  alias Tailcall.Repo

  alias Tailcall.Accounts
  alias Tailcall.Core.Customers
  alias Tailcall.Core.Customers.Customer
  alias Tailcall.Billing.Prices
  alias Tailcall.Billing.Prices.Price
  alias Tailcall.Billing.Subscriptions
  alias Tailcall.Billing.Subscriptions.{Subscription, SubscriptionItem}
  alias Tailcall.Billing.Invoices
  alias Tailcall.Billing.Invoices.Invoice
  alias Tailcall.Billing.InvoiceItems.{InvoiceItem, InvoiceItemQueryable}

  @default_order_by [desc: :id]
  @default_page_number 1
  @default_page_size 100

  @spec list_invoice_items(keyword) :: %{data: [InvoiceItem.t()], total: integer}
  def list_invoice_items(opts \\ []) do
    order_by_fields = list_order_by_fields(opts)

    page_number = Keyword.get(opts, :page_number, @default_page_number)
    page_size = Keyword.get(opts, :page_size, @default_page_size)

    query = invoice_item_queryable(opts)

    count = query |> Repo.aggregate(:count, :id)

    invoice_items =
      query
      |> order_by(^order_by_fields)
      |> InvoiceItemQueryable.paginate(page_number, page_size)
      |> Repo.all()

    %{total: count, data: invoice_items}
  end

  @spec get_invoice!(binary, keyword) :: InvoiceItem.t()
  def get_invoice!(id, opts \\ []) when is_binary(id) do
    filters = opts |> Keyword.get(:filters, []) |> Keyword.put(:id, id)

    opts
    |> Keyword.put(:filters, filters)
    |> invoice_item_queryable()
    |> Repo.one!()
  end

  @spec get_invoice(binary, keyword) :: InvoiceItem.t() | nil
  def get_invoice(id, opts \\ []) when is_binary(id) do
    filters = opts |> Keyword.get(:filters, []) |> Keyword.put(:id, id)

    opts
    |> Keyword.put(:filters, filters)
    |> invoice_item_queryable()
    |> Repo.one()
  end

  @spec create_invoice_item(map()) :: {:ok, InvoiceItem.t()} | {:error, Ecto.Changeset.t()}
  def create_invoice_item(attrs) when is_map(attrs) do
    Multi.new()
    |> Multi.insert(
      :invoice_item,
      %InvoiceItem{}
      |> InvoiceItem.create_changeset(attrs)
      |> prepare_create_changes()
    )
    |> Repo.transaction()
    |> case do
      {:ok, %{invoice_item: %InvoiceItem{} = invoice_item}} -> {:ok, invoice_item}
      {:error, _, changeset, _} -> {:error, changeset}
    end
  end

  @spec create_invoice_items(list, keyword) :: {:ok, integer}
  def create_invoice_items(entries, opts \\ []) when is_list(entries) do
    utc_now = Keyword.get(opts, :created_at, DateTime.utc_now()) |> DateTime.truncate(:second)

    entries = entries |> Enum.map(&Map.merge(&1, %{inserted_at: utc_now, updated_at: utc_now}))
    {num_of_entries, _} = Repo.insert_all(InvoiceItem, entries)
    {:ok, num_of_entries}
  end

  @spec build_invoice_item!(Customer.t(), Price.t(), Subscription.t(), SubscriptionItem.t(), map) ::
          map
  def build_invoice_item!(
        %Customer{account_id: account_id, livemode: livemode} = customer,
        %Price{} = price,
        %Subscription{} = subscription,
        %SubscriptionItem{} = subscription_item,
        attrs
      )
      when price.account_id == account_id and price.livemode == livemode and
             subscription.account_id == account_id and subscription.livemode == livemode and
             subscription_item.subscription_id == subscription.id and is_map(attrs) do
    amount = Map.fetch!(attrs, :amount)
    proration? = Map.fetch!(attrs, :is_proration)
    discountable? = if proration?, do: false, else: Map.fetch!(attrs, :is_discountable)
    quantity = Map.fetch!(attrs, :quantity)

    {unit_amount, unit_amount_decimal} =
      if price.unit_amount * quantity == amount,
        do: {price.unit_amount, price.unit_amount_decimal},
        else: {amount, Decimal.new(amount)}

    %{
      account_id: account_id,
      customer_id: customer.id,
      price_id: price.id,
      subscription_id: subscription.id,
      subscription_item_id: subscription_item.id,
      amount: amount,
      created_at: Map.get(attrs, :created_at, DateTime.utc_now()) |> DateTime.truncate(:second),
      currency: price.currency,
      description: Map.fetch!(attrs, :description),
      is_discountable: discountable?,
      is_proration: proration?,
      livemode: livemode,
      metadata: Map.get(attrs, :metadata, %{}),
      period_start: Map.fetch!(attrs, :period_start) |> DateTime.truncate(:second),
      period_end: Map.fetch!(attrs, :period_end) |> DateTime.truncate(:second),
      quantity: quantity,
      unit_amount: unit_amount,
      unit_amount_decimal: unit_amount_decimal
    }
  end

  @spec bind_invoice_item_to_invoice(InvoiceItem.t(), Invoice.t()) ::
          {:ok, InvoiceItem.t()} | {:error, Ecto.Changeset.t()}
  def bind_invoice_item_to_invoice(
        %InvoiceItem{} = invoice_item,
        %Invoice{id: invoice_id} = invoice
      )
      when invoice_item.customer_id == invoice.customer_id and
             invoice_item.livemode == invoice.livemode do
    invoice_item
    |> Ecto.Changeset.change(%{invoice_id: invoice_id})
    |> Repo.update()
  end

  @spec invoice_item_queryable(keyword) :: Ecto.Queryable.t()
  def invoice_item_queryable(opts \\ []) do
    filters = Keyword.get(opts, :filters, [])
    includes = Keyword.get(opts, :includes, []) |> Enum.concat([:price]) |> Enum.uniq()

    InvoiceItemQueryable.queryable()
    |> InvoiceItemQueryable.filter(filters)
    |> InvoiceItemQueryable.with_preloads(includes)
  end

  defp prepare_create_changes(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp prepare_create_changes(changeset) do
    changeset
    |> Ecto.Changeset.prepare_changes(fn changeset ->
      changeset
      |> assoc_constraint_account()
      |> assoc_constraint_customer()
      |> assoc_constraint_price()
      |> assoc_constraint_subscription()
      |> put_unit_amount_according_to_price()
      |> put_currency_according_to_price()
    end)
  end

  defp assoc_constraint_account(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp assoc_constraint_account(%Ecto.Changeset{valid?: true} = changeset) do
    account_id = Ecto.Changeset.get_field(changeset, :account_id)
    account = Accounts.get_account(account_id)

    if account do
      changeset |> Ecto.Changeset.put_change(:account, account)
    else
      changeset |> Ecto.Changeset.add_error(:account, "does not exist")
    end
  end

  defp assoc_constraint_customer(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp assoc_constraint_customer(%Ecto.Changeset{valid?: true} = changeset) do
    account_id = Ecto.Changeset.get_field(changeset, :account_id)
    customer_id = Ecto.Changeset.get_field(changeset, :customer_id)
    livemode = Ecto.Changeset.get_field(changeset, :livemode)

    customer =
      Customers.get_customer(customer_id, filters: [account_id: account_id, livemode: livemode])

    if customer do
      changeset |> Ecto.Changeset.put_change(:customer, customer)
    else
      changeset |> Ecto.Changeset.add_error(:customer, "does not exist")
    end
  end

  defp assoc_constraint_price(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp assoc_constraint_price(%Ecto.Changeset{valid?: true} = changeset) do
    account_id = Ecto.Changeset.get_field(changeset, :account_id)
    price_id = Ecto.Changeset.get_field(changeset, :price_id)
    livemode = Ecto.Changeset.get_field(changeset, :livemode)

    price = Prices.get_price(price_id, filters: [account_id: account_id, livemode: livemode])

    if price do
      changeset |> Ecto.Changeset.put_change(:price, price)
    else
      changeset |> Ecto.Changeset.add_error(:price, "does not exist")
    end
  end

  defp assoc_constraint_subscription(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp assoc_constraint_subscription(%Ecto.Changeset{valid?: true} = changeset) do
    account_id = Ecto.Changeset.get_field(changeset, :account_id)
    subscription_id = Ecto.Changeset.get_field(changeset, :subscription_id)
    livemode = Ecto.Changeset.get_field(changeset, :livemode)

    subscription =
      Subscriptions.get_subscription(subscription_id,
        filters: [account_id: account_id, livemode: livemode]
      )

    if subscription do
      changeset |> Ecto.Changeset.put_change(:subscription, subscription)
    else
      changeset |> Ecto.Changeset.add_error(:subscription, "does not exist")
    end
  end

  defp put_unit_amount_according_to_price(%Ecto.Changeset{valid?: false} = changeset),
    do: changeset

  defp put_unit_amount_according_to_price(%Ecto.Changeset{valid?: true} = changeset) do
    price = Ecto.Changeset.get_field(changeset, :price)

    changeset
    |> Ecto.Changeset.put_change(:unit_amount, price.unit_amount)
    |> Ecto.Changeset.put_change(:unit_amount_decimal, price.unit_amount_decimal)
  end

  defp put_currency_according_to_price(%Ecto.Changeset{valid?: false} = changeset),
    do: changeset

  defp put_currency_according_to_price(%Ecto.Changeset{valid?: true} = changeset) do
    price = Ecto.Changeset.get_field(changeset, :price)

    changeset
    |> Ecto.Changeset.put_change(:currency, price.currency)
  end

  defp list_order_by_fields(opts) do
    Keyword.get(opts, :order_by_fields, [])
    |> case do
      [] -> @default_order_by
      [_ | _] = order_by_fields -> order_by_fields
    end
  end
end
