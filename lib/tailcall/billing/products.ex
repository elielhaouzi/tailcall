defmodule Tailcall.Billing.Products do
  @moduledoc """
  The Products context.
  """
  import Ecto.Query, only: [order_by: 2]

  alias Tailcall.Repo
  alias Tailcall.Accounts

  alias Tailcall.Billing.Products.{Product, ProductQueryable}

  @default_order_by [asc: :id]
  @default_page_number 1
  @default_page_size 100

  @spec list_products(keyword) :: %{data: [Product.t()], total: integer}
  def list_products(opts \\ []) do
    order_by_fields = list_order_by_fields(opts)

    page_number = Keyword.get(opts, :page_number, @default_page_number)
    page_size = Keyword.get(opts, :page_size, @default_page_size)

    query = product_queryable(opts)

    count = query |> Repo.aggregate(:count, :id)

    products =
      query
      |> order_by(^order_by_fields)
      |> ProductQueryable.paginate(page_number, page_size)
      |> Repo.all()

    %{total: count, data: products}
  end

  @spec create_product(map()) :: {:ok, Product.t()} | {:error, Ecto.Changeset.t()}
  def create_product(attrs) when is_map(attrs) do
    %Product{}
    |> Product.create_changeset(attrs)
    |> validate_create_changes()
    |> Repo.insert()
  end

  @spec get_product(binary) :: Product.t() | nil
  def get_product(id) when is_binary(id) do
    Product
    |> Repo.get(id)
  end

  @spec get_product!(binary) :: Product.t()
  def get_product!(id) when is_binary(id) do
    Product
    |> Repo.get!(id)
  end

  @spec update_product(Product.t(), map()) :: {:ok, Product.t()} | {:error, Ecto.Changeset.t()}
  def update_product(%Product{deleted_at: nil} = product, attrs) when is_map(attrs) do
    product
    |> Product.update_changeset(attrs)
    |> Repo.update()
  end

  @spec delete_product(Product.t(), DateTime.t()) ::
          {:ok, Product.t()} | {:error, Ecto.Changeset.t()}
  def delete_product(%Product{deleted_at: nil} = product, %DateTime{} = delete_at) do
    product
    |> Product.delete_changeset(%{deleted_at: delete_at})
    |> Repo.update()
  end

  defp validate_create_changes(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp validate_create_changes(changeset) do
    Ecto.Changeset.prepare_changes(changeset, fn changeset ->
      changeset
      |> assoc_constraint_account()
    end)
  end

  defp assoc_constraint_account(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp assoc_constraint_account(%Ecto.Changeset{valid?: true} = changeset) do
    account_id = Ecto.Changeset.get_field(changeset, :account_id)

    if Accounts.account_exists?(account_id) do
      changeset
    else
      changeset |> Ecto.Changeset.add_error(:account, "does not exist")
    end
  end

  @spec product_queryable(keyword) :: Ecto.Queryable.t()
  def product_queryable(opts \\ []) do
    filters = Keyword.get(opts, :filters, [])

    ProductQueryable.queryable()
    |> ProductQueryable.filter(filters)
  end

  defp list_order_by_fields(opts) do
    Keyword.get(opts, :order_by_fields, [])
    |> case do
      [] -> @default_order_by
      [_ | _] = order_by_fields -> order_by_fields
    end
  end
end
