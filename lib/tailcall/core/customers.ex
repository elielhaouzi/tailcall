defmodule Tailcall.Core.Customers do
  @moduledoc """
  The Customer context.
  """
  import Ecto.Query, only: [order_by: 2]

  alias Tailcall.Repo

  alias Tailcall.Accounts
  alias Tailcall.Core.Customers.{Customer, CustomerQueryable}

  @default_order_by [desc: :id]
  @default_page_number 1
  @default_page_size 100

  @spec list_customers(keyword) :: %{data: [Customer.t()], total: integer}
  def list_customers(opts \\ []) do
    order_by_fields = list_order_by_fields(opts)

    page_number = Keyword.get(opts, :page_number, @default_page_number)
    page_size = Keyword.get(opts, :page_size, @default_page_size)

    query = customer_queryable(opts)

    count = query |> Repo.aggregate(:count, :id)

    customers =
      query
      |> order_by(^order_by_fields)
      |> CustomerQueryable.paginate(page_number, page_size)
      |> Repo.all()

    %{total: count, data: customers}
  end

  @spec create_customer(map()) :: {:ok, Customer.t()} | {:error, Ecto.Changeset.t()}
  def create_customer(attrs) when is_map(attrs) do
    %Customer{}
    |> Customer.create_changeset(attrs)
    |> validate_create_changes()
    |> Repo.insert()
  end

  @spec get_customer(binary) :: Customer.t() | nil
  def get_customer(id) when is_binary(id), do: Customer |> Repo.get(id)

  @spec get_customer!(binary) :: Customer.t() | nil
  def get_customer!(id) when is_binary(id), do: Customer |> Repo.get!(id)

  @spec customer_exists?(binary) :: boolean
  def customer_exists?(id) when is_binary(id) do
    [filters: [id: id]]
    |> customer_queryable()
    |> Repo.exists?()
  end

  @spec update_customer(Customer.t(), map()) :: {:ok, Customer.t()} | {:error, Ecto.Changeset.t()}
  def update_customer(%Customer{deleted_at: nil} = customer, attrs) when is_map(attrs) do
    customer
    |> Customer.update_changeset(attrs)
    |> Repo.update()
  end

  @spec delete_customer(Customer.t(), DateTime.t()) ::
          {:ok, Customer.t()} | {:error, Ecto.Changeset.t()}
  def delete_customer(%Customer{deleted_at: nil} = customer, %DateTime{} = delete_at) do
    customer
    |> Customer.delete_changeset(%{deleted_at: delete_at})
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

  defp customer_queryable(opts) do
    filters = Keyword.get(opts, :filters, [])

    CustomerQueryable.queryable()
    |> CustomerQueryable.filter(filters)
  end

  defp list_order_by_fields(opts) do
    Keyword.get(opts, :order_by_fields, [])
    |> case do
      [] -> @default_order_by
      [_ | _] = order_by_fields -> order_by_fields
    end
  end
end
