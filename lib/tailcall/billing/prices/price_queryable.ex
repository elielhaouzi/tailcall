defmodule Tailcall.Billing.Prices.PriceQueryable do
  use AntlUtilsEcto.Queryable,
    base_schema: Tailcall.Billing.Prices.Price

  import Ecto.Query, only: [preload: 2]

  @spec with_preloads(Ecto.Queryable.t(), list(atom())) :: Ecto.Queryable.t()
  def with_preloads(queryable, includes) when is_list(includes) do
    Enum.reduce(includes, queryable, fn include, queryable ->
      queryable |> with_preload(include)
    end)
  end

  defp with_preload(queryable, :tiers) do
    queryable |> preload([:tiers])
  end

  defp filter_by_field({:deleted_at, %DateTime{} = datetime}, queryable) do
    queryable
    |> AntlUtilsEcto.Query.where_period_status(:ended, :created_at, :deleted_at, datetime)
  end

  defp filter_by_field({:ongoing_at, %DateTime{} = datetime}, queryable) do
    queryable
    |> AntlUtilsEcto.Query.where_period_status(:ongoing, :created_at, :deleted_at, datetime)
  end
end
