defmodule Tailcall.Core.Customers.CustomerQueryable do
  use AntlUtilsEcto.Queryable,
    base_schema: Tailcall.Core.Customers.Customer

  defp filter_by_field({:deleted_at, %DateTime{} = datetime}, queryable) do
    queryable
    |> AntlUtilsEcto.Query.where_period_status(:ended, :created_at, :deleted_at, datetime)
  end

  defp filter_by_field({:ongoing_at, %DateTime{} = datetime}, queryable) do
    queryable
    |> AntlUtilsEcto.Query.where_period_status(:ongoing, :created_at, :deleted_at, datetime)
  end
end
