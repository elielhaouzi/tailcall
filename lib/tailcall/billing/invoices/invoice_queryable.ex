defmodule Tailcall.Billing.Invoices.InvoiceQueryable do
  use AntlUtilsEcto.Queryable,
    base_schema: Tailcall.Billing.Invoices.Invoice

  import Ecto.Query, only: [preload: 2]

  alias Tailcall.Accounts
  alias Tailcall.Billing.Subscriptions

  @spec with_preloads(Ecto.Queryable.t(), list(atom())) :: Ecto.Queryable.t()
  def with_preloads(queryable, includes) when is_list(includes) do
    Enum.reduce(includes, queryable, fn include, queryable ->
      queryable |> with_preload(include)
    end)
  end

  defp with_preload(queryable, :line_items) do
    queryable |> preload_invoice_line_items()
  end

  defp with_preload(queryable, :account) do
    queryable |> preload_account()
  end

  defp with_preload(queryable, :subscription) do
    queryable |> preload_subscription()
  end

  defp preload_invoice_line_items(queryable) do
    queryable |> preload([:line_items])
  end

  defp preload_account(queryable) do
    account_query = Accounts.account_queryable() |> Ecto.Queryable.to_query()

    queryable |> preload(account: ^account_query)
  end

  defp preload_subscription(queryable) do
    subscription_query = Subscriptions.subscription_queryable() |> Ecto.Queryable.to_query()

    queryable |> preload(subscription: ^subscription_query)
  end
end
