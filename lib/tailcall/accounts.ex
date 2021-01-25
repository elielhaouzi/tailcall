defmodule Tailcall.Accounts do
  @moduledoc """
  Accounts context
  """

  # import Ecto.Query, only: [order_by: 2]

  alias Tailcall.Repo

  alias Tailcall.Accounts.{Account, AccountQueryable}
  alias Tailcall.Accounts.ApiKeys
  alias Tailcall.Accounts.ApiKeys.ApiKey

  # @default_order_by [asc: :id]
  # @default_page_number 1
  # @default_page_size 100

  # @spec list_accounts(keyword) :: %{data: [Account.t()], total: integer}
  # def list_accounts(opts \\ []) do
  #   order_by_fields = list_order_by_fields(opts)

  #   page_number = Keyword.get(opts, :page_number, @default_page_number)
  #   page_size = Keyword.get(opts, :page_size, @default_page_size)

  #   query = account_queryable(opts)

  #   count = query |> Repo.aggregate(:count, :id)

  #   accounts =
  #     query
  #     |> order_by(^order_by_fields)
  #     |> AccountQueryable.paginate(page_number, page_size)
  #     |> Repo.all()

  #   %{total: count, data: accounts}
  # end

  # @spec create_account(map) :: {:ok, Account.t()} | {:error, Ecto.Changeset.t()}
  # def create_account(attrs) do
  #   %Account{}
  #   |> Account.create_changeset(attrs)
  #   |> Repo.insert()
  # end

  # @spec get_account(binary) :: Account.t() | nil
  # def get_account(id) when is_binary(id), do: Account |> Repo.get(id)

  # @spec get_account!(binary) :: Account.t()
  # def get_account!(id) when is_binary(id), do: Account |> Repo.get!(id)

  @spec authenticate(map) ::
          {:ok, %{api_key: map, account: map}} | {:error, :unauthorized | :forbidden}
  def authenticate(%{"api_key" => secret} = attrs) when is_binary(secret) do
    with {:api_key, %ApiKey{} = api_key} <-
           {:api_key, ApiKeys.get_api_key_by([secret: secret], includes: [:account])},
         {:expired, false} <- {:expired, ApiKeys.expired?(api_key)} do
      {:ok, _api_key_usage} = ApiKeys.touch(api_key, attrs)

      {:ok, %{api_key: api_key, account: api_key.account}}
    else
      {:api_key, nil} -> {:error, :unauthorized}
      {:expired, true} -> {:error, :forbidden}
    end
  end

  def authenticate(%{"api_key" => _key}), do: {:error, :unauthorized}

  @spec livemode?(ApiKey.t()) :: boolean
  def livemode?(%ApiKey{livemode: livemode}), do: livemode

  @spec account_exists?(binary) :: boolean
  def account_exists?(id) when is_binary(id) do
    [filters: [id: id]]
    |> account_queryable()
    |> Repo.exists?()
  end

  defp account_queryable(opts) do
    filters = Keyword.get(opts, :filters, [])

    AccountQueryable.queryable()
    |> AccountQueryable.filter(filters)
  end

  # defp list_order_by_fields(opts) do
  #   Keyword.get(opts, :order_by_fields, [])
  #   |> case do
  #     [] -> @default_order_by
  #     [_ | _] = order_by_fields -> order_by_fields
  #   end
  # end
end
