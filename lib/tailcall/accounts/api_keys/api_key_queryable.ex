defmodule Tailcall.Accounts.ApiKeys.ApiKeyQueryable do
  use AntlUtilsEcto.Queryable,
    base_schema: Tailcall.Accounts.ApiKeys.ApiKey

  import Ecto.Query, only: [preload: 2, select_merge: 3, where: 2]

  @spec with_preloads(Ecto.Queryable.t(), [atom], keyword) :: Ecto.Queryable.t()
  def with_preloads(queryable, includes, opts \\ []) when is_list(includes) and is_list(opts) do
    filters = opts |> Keyword.get(:filters, [])

    includes
    |> Enum.reduce(queryable, fn include, queryable ->
      queryable |> with_preload(include, filters)
    end)
  end

  defp with_preload(queryable, :account, _filters) do
    queryable |> preload_account()
  end

  defp with_preload(queryable, :last_usage, _filters) do
    queryable |> preload_last_usage()
  end

  defp preload_account(queryable) do
    queryable |> preload([:account])
  end

  defp preload_last_usage(queryable) do
    queryable
    |> select_merge(
      [api_key],
      %{
        last_used_at:
          type(
            fragment(
              "SELECT used_at FROM api_key_usages WHERE api_key_id = ? ORDER BY used_at DESC, id DESC LIMIT 1",
              api_key.id
            ),
            :utc_datetime_usec
          ),
        last_used_ip_address:
          fragment(
            "SELECT ip_address FROM api_key_usages WHERE api_key_id = ? ORDER BY used_at DESC, id DESC LIMIT 1",
            api_key.id
          )
      }
    )
  end

  defp filter_by_field({:ongoing_at, %DateTime{} = datetime}, queryable) do
    queryable
    |> AntlUtilsEcto.Query.where_period_status(:ongoing, :created_at, :expired_at, datetime)
  end
end
