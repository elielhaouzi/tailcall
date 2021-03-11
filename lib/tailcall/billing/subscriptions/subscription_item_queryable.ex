defmodule Tailcall.Billing.Subscriptions.SubscriptionItemQueryable do
  use AntlUtilsEcto.Queryable,
    base_schema: Tailcall.Billing.Subscriptions.SubscriptionItem

  import Ecto.Query, only: [preload: 2]

  alias Tailcall.Billing.Prices

  @spec with_preloads(Ecto.Queryable.t(), list(atom())) :: Ecto.Queryable.t()
  def with_preloads(queryable, includes) when is_list(includes) do
    Enum.reduce(includes, queryable, fn include, queryable ->
      queryable |> with_preload(include)
    end)
  end

  defp with_preload(queryable, :price) do
    queryable |> preload_price()
  end

  defp with_preload(queryable, {:price, :product}) do
    queryable |> preload_price(includes: [:product])
  end

  defp preload_price(queryable, opts \\ []) do
    includes = opts |> Keyword.get(:includes, [])

    price_query = Prices.price_queryable(includes: includes) |> Ecto.Queryable.to_query()

    queryable |> preload(price: ^price_query)
  end

  defp filter_by_field({:ongoing_at, %DateTime{} = datetime}, queryable) do
    queryable
    |> AntlUtilsEcto.Query.where_period_status(:ongoing, :created_at, :deleted_at, datetime)
  end
end
