defmodule Tailcall.Billing.InvoiceItems.InvoiceItemQueryable do
  use AntlUtilsEcto.Queryable,
    base_schema: Tailcall.Billing.InvoiceItems.InvoiceItem

  import Ecto.Query, only: [preload: 2]

  alias Tailcall.Billing.Prices

  @spec with_preloads(Ecto.Queryable.t(), list(atom())) :: Ecto.Queryable.t()
  def with_preloads(queryable, includes) when is_list(includes) do
    Enum.reduce(includes, queryable, fn include, queryable ->
      queryable |> with_preload(include)
    end)
  end

  # defp with_preload(queryable, :discounts) do
  # end

  # defp with_preload(queryable, :tax_rates) do
  # end

  defp with_preload(queryable, :price) do
    queryable |> preload_price()
  end

  defp preload_price(queryable) do
    price_query = Prices.price_queryable() |> Ecto.Queryable.to_query()

    queryable |> preload(price: ^price_query)
  end
end
