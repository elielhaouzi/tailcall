defmodule Tailcall.Users do
  @moduledoc """
  The User context.
  """
  use Annacl

  import Ecto.Query, only: [order_by: 2]

  alias Tailcall.Repo

  alias Tailcall.Users.{User, UserQueryable}

  @default_order_by [asc: :id]
  @default_page_number 1
  @default_page_size 100

  @spec list_users(keyword) :: %{data: [User.t()], total: integer}
  def list_users(opts \\ []) do
    order_by_fields = list_order_by_fields(opts)

    page_number = Keyword.get(opts, :page_number, @default_page_number)
    page_size = Keyword.get(opts, :page_size, @default_page_size)

    query = user_queryable(opts)

    count = query |> Repo.aggregate(:count, :id)

    users =
      query
      |> order_by(^order_by_fields)
      |> UserQueryable.paginate(page_number, page_size)
      |> Repo.all()

    %{total: count, data: users}
  end

  @spec create_user(map) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def create_user(attrs) do
    %User{}
    |> User.create_changeset(attrs)
    |> Repo.insert()
  end

  @spec get_user(binary) :: User.t() | nil
  def get_user(id) when is_binary(id), do: User |> Repo.get(id)

  @spec get_user!(binary) :: User.t()
  def get_user!(id) when is_binary(id), do: User |> Repo.get!(id)

  @spec get_user_by([{:email, binary}]) :: User.t() | nil
  def get_user_by(email: email) when is_binary(email), do: User |> Repo.get_by(email: email)

  @spec user_exists?(binary) :: boolean
  def user_exists?(id) when is_binary(id) do
    [filters: [id: id]]
    |> user_queryable()
    |> Repo.exists?()
  end

  @spec update_user(User.t(), map) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def update_user(%User{deleted_at: nil} = user, attrs) when is_map(attrs) do
    user
    |> User.update_changeset(attrs)
    |> Repo.update()
  end

  @spec delete_user(User.t(), map) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def delete_user(%User{deleted_at: nil} = user, %DateTime{} = delete_at) do
    user
    |> User.delete_changeset(%{deleted_at: delete_at})
    |> Repo.update()
  end

  @spec user_queryable(keyword) :: Ecto.Queryable.t()
  def user_queryable(opts) do
    filters = Keyword.get(opts, :filters, [])

    UserQueryable.queryable()
    |> UserQueryable.filter(filters)
  end

  defp list_order_by_fields(opts) do
    Keyword.get(opts, :order_by_fields, [])
    |> case do
      [] -> @default_order_by
      [_ | _] = order_by_fields -> order_by_fields
    end
  end
end
