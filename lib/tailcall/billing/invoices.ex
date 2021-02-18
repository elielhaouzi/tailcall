defmodule Tailcall.Billing.Invoices do
  @moduledoc """
  The Invoices context.
  """

  import Ecto.Query, only: [order_by: 2]

  alias Ecto.Multi
  alias Tailcall.Repo

  alias Tailcall.Accounts
  alias Tailcall.Core.Customers
  alias Tailcall.Billing.Subscriptions
  alias Tailcall.Billing.Invoices.{Invoice, InvoiceQueryable}
  alias Tailcall.Billing.Invoices.Workers.AutomaticCollectionWorker

  @default_order_by [asc: :id]
  @default_page_number 1
  @default_page_size 100

  @spec list_invoices(keyword) :: %{data: [Invoice.t()], total: integer}
  def list_invoices(opts \\ []) do
    order_by_fields = list_order_by_fields(opts)

    page_number = Keyword.get(opts, :page_number, @default_page_number)
    page_size = Keyword.get(opts, :page_size, @default_page_size)

    query = invoice_queryable(opts)

    count = query |> Repo.aggregate(:count, :id)

    invoices =
      query
      |> order_by(^order_by_fields)
      |> InvoiceQueryable.paginate(page_number, page_size)
      |> Repo.all()

    %{total: count, data: invoices}
  end

  @spec get_invoice!(binary, keyword) :: Invoice.t()
  def get_invoice!(id, opts \\ []) when is_binary(id) do
    filters = opts |> Keyword.get(:filters, []) |> Keyword.put(:id, id)

    opts
    |> Keyword.put(:filters, filters)
    |> invoice_queryable()
    |> Repo.one!()
  end

  @spec get_invoice(binary, keyword) :: Invoice.t() | nil
  def get_invoice(id, opts \\ []) when is_binary(id) do
    filters = opts |> Keyword.get(:filters, []) |> Keyword.put(:id, id)

    opts
    |> Keyword.put(:filters, filters)
    |> invoice_queryable()
    |> Repo.one()
  end

  @spec create_invoice(map()) :: {:ok, Invoice.t()} | {:error, Ecto.Changeset.t()}
  def create_invoice(attrs) when is_map(attrs) do
    status = Map.get(attrs, :status, Invoice.statuses().draft)
    total = Map.get(attrs, :total)

    attrs =
      attrs
      |> Map.merge(%{
        created_at: DateTime.utc_now(),
        status: status,
        amount_due: total,
        amount_paid: 0,
        amount_remaining: total
      })

    Multi.new()
    |> Multi.insert(
      :invoice,
      %Invoice{}
      |> Invoice.create_changeset(attrs)
      |> prepare_create_changes()
    )
    |> Multi.run(:auto_advance, fn
      _repo, %{invoice: %{id: id, auto_advance: true, created_at: created_at}} ->
        %{id: id}
        |> AutomaticCollectionWorker.new(scheduled_at: DateTime.add(created_at, 3600, :second))
        |> Oban.insert()

      _repo, %{invoice: %{auto_advance: false}} ->
        {:ok, nil}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{invoice: %Invoice{} = invoice}} -> {:ok, invoice}
      {:error, _, changeset, _} -> {:error, changeset}
    end
  end

  @spec finalize_invoice(Invoice.t()) :: {:ok, Invoice.t()} | {:error, Ecto.Changeset.t()}
  def finalize_invoice(
        %Invoice{status: "draft", account: account, number: invoice_number} = invoice
      ) do
    Multi.new()
    |> Multi.run(:next_invoice_sequence, fn _, %{} ->
      if Accounts.account_level_numbering_scheme?(account) do
        {:ok, Accounts.next_invoice_sequence!(account, invoice.livemode)}
      end
    end)
    |> Multi.update(:invoice, fn %{next_invoice_sequence: next_invoice_sequence} ->
      invoice_prefix = invoice_number |> String.trim_trailing("-DRAFT")

      next_invoice_sequence =
        next_invoice_sequence |> Integer.to_string() |> String.pad_leading(5, "0")

      invoice
      |> Ecto.Changeset.change(%{
        status: Invoice.statuses().open,
        number: "#{invoice_prefix}-#{next_invoice_sequence}"
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{invoice: invoice}} -> {:ok, invoice}
      {:error, _, changeset, _} -> {:error, changeset}
    end
  end

  def finalize_invoice(%Invoice{}), do: {:error, :invalid_action}

  @spec past_due?(Invoice.t()) :: boolean
  def past_due?(%Invoice{due_date: due_date}),
    do: AntlUtilsElixir.DateTime.Comparison.gte?(DateTime.utc_now(), due_date)

  @spec invoice_queryable(keyword) :: Ecto.Queryable.t()
  def invoice_queryable(opts \\ []) do
    filters = Keyword.get(opts, :filters, [])
    includes = Keyword.get(opts, :includes, []) |> Enum.concat([:line_items]) |> Enum.uniq()

    InvoiceQueryable.queryable()
    |> InvoiceQueryable.filter(filters)
    |> InvoiceQueryable.with_preloads(includes)
  end

  defp prepare_create_changes(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp prepare_create_changes(changeset) do
    changeset
    |> Ecto.Changeset.prepare_changes(fn changeset ->
      changeset
      |> assoc_constraint_account()
      |> assoc_constraint_customer()
      |> assoc_constraint_subscription()
      |> maybe_put_due_date()
      |> put_invoice_number()
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

  defp maybe_put_due_date(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp maybe_put_due_date(%Ecto.Changeset{valid?: true} = changeset) do
    account = Ecto.Changeset.get_field(changeset, :account)
    collection_method = Ecto.Changeset.get_field(changeset, :collection_method)
    created_at = Ecto.Changeset.get_field(changeset, :created_at)
    due_date = Ecto.Changeset.get_field(changeset, :due_date)

    if collection_method == Invoice.collection_methods().send_invoice and is_nil(due_date) do
      days_until_due = account |> Accounts.days_until_due()

      changeset
      |> Ecto.Changeset.put_change(
        :due_date,
        DateTime.add(created_at, days_until_due * 24 * 3600, :second)
      )
    else
      changeset
    end
  end

  defp put_invoice_number(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp put_invoice_number(%Ecto.Changeset{valid?: true} = changeset) do
    account = Ecto.Changeset.get_field(changeset, :account)

    if Accounts.account_level_numbering_scheme?(account) do
      invoice_prefix = Accounts.invoice_prefix(account)

      changeset |> Ecto.Changeset.put_change(:number, "#{invoice_prefix}-DRAFT")
    else
      changeset
    end
  end

  defp list_order_by_fields(opts) do
    Keyword.get(opts, :order_by_fields, [])
    |> case do
      [] -> @default_order_by
      [_ | _] = order_by_fields -> order_by_fields
    end
  end
end
