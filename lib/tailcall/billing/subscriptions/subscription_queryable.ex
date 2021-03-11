defmodule Tailcall.Billing.Subscriptions.SubscriptionQueryable do
  use AntlUtilsEcto.Queryable,
    base_schema: Tailcall.Billing.Subscriptions.Subscription

  import Ecto.Query, only: [last: 2, preload: 2, select_merge: 3]

  alias Tailcall.Core.Customers
  alias Tailcall.Billing.Invoices
  alias Tailcall.Billing.Subscriptions.SubscriptionItemQueryable

  @spec with_preloads(Ecto.Queryable.t(), list(atom())) :: Ecto.Queryable.t()
  def with_preloads(queryable, includes) when is_list(includes) do
    Enum.reduce(includes, queryable, fn include, queryable ->
      queryable |> with_preload(include)
    end)
  end

  defp with_preload(queryable, :customer) do
    queryable |> preload_customer()
  end

  defp with_preload(queryable, :latest_invoice_id) do
    queryable |> with_latest_invoice_id()
  end

  defp with_preload(queryable, :latest_invoice) do
    queryable |> preload_latest_invoice()
  end

  defp with_preload(queryable, :items) do
    queryable |> preload_subscription_items()
  end

  defp with_preload(queryable, items: includes) do
    queryable |> preload_subscription_items(includes: includes)
  end

  @spec with_latest_invoice_id(Ecto.Queryable.t()) :: Ecto.Queryable.t()
  defp with_latest_invoice_id(queryable) do
    queryable
    |> select_merge(
      [subscription],
      %{
        latest_invoice_id:
          fragment(
            "SELECT id FROM invoices WHERE subscription_id = ? ORDER BY id DESC LIMIT 1",
            subscription.id
          )
      }
    )
  end

  defp preload_customer(queryable) do
    customer_query = Customers.customer_queryable() |> Ecto.Queryable.to_query()

    queryable |> preload(customer: ^customer_query)
  end

  defp preload_latest_invoice(queryable) do
    latest_invoice_query = Invoices.invoice_queryable() |> last(:id) |> Ecto.Queryable.to_query()

    queryable |> preload(latest_invoice: ^latest_invoice_query)
  end

  defp preload_subscription_items(queryable, opts \\ []) do
    includes = opts |> Keyword.get(:includes, [])

    subscription_item_query =
      SubscriptionItemQueryable.queryable()
      |> SubscriptionItemQueryable.with_preloads(includes)
      |> SubscriptionItemQueryable.filter(ongoing_at: DateTime.utc_now())
      |> Ecto.Queryable.to_query()

    queryable |> preload(items: ^subscription_item_query)
  end
end
