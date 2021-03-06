defmodule Tailcall.Accounts.AccountQueryable do
  use AntlUtilsEcto.Queryable,
    base_schema: Tailcall.Accounts.Account

  defp filter_by_field({:deleted_at, %DateTime{} = datetime}, queryable) do
    queryable
    |> AntlUtilsEcto.Query.where_period_status(:ended, :created_at, :deleted_at, datetime)
  end

  defp filter_by_field({:ongoing_at, %DateTime{} = datetime}, queryable) do
    queryable
    |> AntlUtilsEcto.Query.where_period_status(:ongoing, :created_at, :deleted_at, datetime)
  end
end
