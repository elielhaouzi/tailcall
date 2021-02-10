defmodule Tailcall.Billing.Invoices do
  @moduledoc """
  The Invoices context.
  """

  import Ecto.Query, only: [order_by: 2]

  alias Ecto.Multi
  alias Tailcall.Repo

  alias Tailcall.Accounts
  alias Tailcall.Core.Customers
  alias Tailcall.Billing.Invoices.{Invoice, InvoiceQueryable}
  alias Tailcall.Billing.Invoices.Workers.AutoAdvanceWorker

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
    |> Multi.insert(:invoice, Invoice.create_changeset(%Invoice{}, attrs))
    |> Oban.insert(:renew_subscription_job, fn %{invoice: invoice} ->
      %{id: invoice.id}
      |> AutoAdvanceWorker.new(scheduled_at: DateTime.add(invoice.created_at, 3600, :second))
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{invoice: %Invoice{} = invoice}} -> {:ok, invoice}
      {:error, _, changeset, _} -> {:error, changeset}
    end
  end

  @spec invoice_queryable(keyword) :: Ecto.Queryable.t()
  def invoice_queryable(opts \\ []) do
    filters = Keyword.get(opts, :filters, [])
    includes = Keyword.get(opts, :includes, []) |> Enum.concat([:line_items]) |> Enum.uniq()

    InvoiceQueryable.queryable()
    |> InvoiceQueryable.filter(filters)
    |> InvoiceQueryable.with_preloads(includes)
  end

  defp list_order_by_fields(opts) do
    Keyword.get(opts, :order_by_fields, [])
    |> case do
      [] -> @default_order_by
      [_ | _] = order_by_fields -> order_by_fields
    end
  end
end
