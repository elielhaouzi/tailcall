defmodule Billing.Accounts.Users do
  @moduledoc """
  The User context.
  """
  alias Billing.Repo

  alias Billing.Accounts.Users.{User, UserQueryable}

  @default_sort_field :inserted_at
  @default_sort_order :asc
  @default_page_number 1
  @default_page_size 100

  @spec list_users(keyword) :: %{data: [User.t()], total: integer}
  def list_users(opts \\ []) do
    sort_field = Keyword.get(opts, :sort_field, @default_sort_field)
    sort_order = Keyword.get(opts, :sort_order, @default_sort_order)

    page_number = Keyword.get(opts, :page_number, @default_page_number)
    page_size = Keyword.get(opts, :page_size, @default_page_size)

    query = user_queryable(opts)

    count = query |> Repo.aggregate(:count, :id)

    users =
      query
      |> UserQueryable.sort(%{field: sort_field, order: sort_order})
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
  def get_user(id) when is_binary(id) do
    User
    |> Repo.get(id)
  end

  @spec get_user!(binary) :: User.t()
  def get_user!(id) when is_binary(id) do
    User
    |> Repo.get!(id)
  end

  @spec get_user_by([{:email, binary}]) :: User.t() | nil
  def get_user_by(email: email) when is_binary(email) do
    User
    |> Repo.get_by(email: email)
  end

  @spec user_exists?(binary) :: boolean
  def user_exists?(id) when is_binary(id) do
    [filters: [id: id]]
    |> user_queryable()
    |> Repo.exists?()
  end

  @spec update_user(User.t(), map) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def update_user(%User{} = user, attrs) when is_map(attrs) do
    user
    |> User.update_changeset(attrs)
    |> Repo.update()
  end

  defp user_queryable(opts) do
    filters = Keyword.get(opts, :filters, [])

    UserQueryable.queryable()
    |> UserQueryable.filter(filters)
  end
end
