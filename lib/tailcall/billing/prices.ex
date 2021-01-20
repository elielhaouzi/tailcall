defmodule Tailcall.Billing.Prices do
  @moduledoc """
  The Prices context.
  """
  import Ecto.Query, only: [order_by: 2]

  alias Tailcall.Repo

  alias Tailcall.Accounts
  alias Tailcall.Billing.Prices.{Price, PriceQueryable}

  @default_order_by [asc: :id]
  @default_page_number 1
  @default_page_size 100

  @spec list_prices(keyword) :: %{data: [Price.t()], total: integer}
  def list_prices(opts \\ []) do
    order_by_fields = list_order_by_fields(opts)

    page_number = Keyword.get(opts, :page_number, @default_page_number)
    page_size = Keyword.get(opts, :page_size, @default_page_size)

    query = price_queryable(opts)

    count = query |> Repo.aggregate(:count, :id)

    prices =
      query
      |> order_by(^order_by_fields)
      |> PriceQueryable.paginate(page_number, page_size)
      |> Repo.all()

    %{total: count, data: prices}
  end

  @spec create_price(map()) :: {:ok, Price.t()} | {:error, Ecto.Changeset.t()}
  def create_price(attrs) when is_map(attrs) do
    %Price{}
    |> Price.create_changeset(attrs)
    |> validate_create_changes()
    |> Repo.insert()
  end

  @spec get_price(binary) :: Price.t() | nil
  def get_price(id) when is_binary(id) do
    Price
    |> Repo.get(id)
  end

  @spec get_price!(binary) :: Price.t() | nil
  def get_price!(id) when is_binary(id) do
    Price
    |> Repo.get!(id)
  end

  @spec update_price(Price.t(), map()) ::
          {:ok, Price.t()} | {:error, Ecto.Changeset.t()}
  def update_price(%Price{deleted_at: nil} = price, attrs) when is_map(attrs) do
    price
    |> Price.update_changeset(attrs)
    |> Repo.update()
  end

  @spec delete_price(Price.t(), DateTime.t()) ::
          {:ok, Price.t()} | {:error, Ecto.Changeset.t()}
  def delete_price(%Price{deleted_at: nil} = price, %DateTime{} = delete_at) do
    price
    |> Price.delete_changeset(%{deleted_at: delete_at})
    |> Repo.update()
  end

  defp validate_create_changes(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp validate_create_changes(changeset) do
    Ecto.Changeset.prepare_changes(changeset, fn changeset ->
      changeset
      |> assoc_constraint_user()
    end)
  end

  defp assoc_constraint_user(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp assoc_constraint_user(%Ecto.Changeset{valid?: true} = changeset) do
    user_id = Ecto.Changeset.get_field(changeset, :user_id)

    if Accounts.user_exists?(user_id) do
      changeset
    else
      changeset |> Ecto.Changeset.add_error(:user, "does not exist")
    end
  end

  defp price_queryable(opts) do
    filters = Keyword.get(opts, :filters, [])
    includes = Keyword.get(opts, :includes, [])

    PriceQueryable.queryable()
    |> PriceQueryable.filter(filters)
    |> PriceQueryable.with_preloads(includes)
  end

  defp list_order_by_fields(opts) do
    Keyword.get(opts, :order_by_fields, [])
    |> case do
      [] -> @default_order_by
      [_ | _] = order_by_fields -> order_by_fields
    end
  end
end