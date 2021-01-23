defmodule Tailcall.Accounts do
  @moduledoc """
  Accounts context
  """
  use Annacl

  alias Tailcall.Accounts.ApiKeys
  alias Tailcall.Accounts.ApiKeys.ApiKey
  alias Tailcall.Accounts.Users
  alias Tailcall.Accounts.Users.User

  @spec authenticate(map) ::
          {:ok, %{api_key: map, user: map}} | {:error, :unauthorized | :forbidden}
  def authenticate(%{"api_key" => secret} = attrs) when is_binary(secret) do
    with {:api_key, %ApiKey{} = api_key} <-
           {:api_key, ApiKeys.get_api_key_by([secret: secret], includes: [:user])},
         {:expired, false} <- {:expired, ApiKeys.expired?(api_key)} do
      {:ok, _api_key_usage} = ApiKeys.touch(api_key, attrs)

      {:ok,
       %{
         api_key: api_key,
         user: api_key.user,
         #  superadmin?: false
         superadmin?: has_role?(api_key.user, Annacl.superadmin_role_name())
       }}
    else
      {:api_key, nil} -> {:error, :unauthorized}
      {:expired, true} -> {:error, :forbidden}
    end
  end

  def authenticate(%{"api_key" => _key}), do: {:error, :unauthorized}

  @spec livemode?(ApiKey.t()) :: boolean
  def livemode?(%ApiKey{livemode: livemode}), do: livemode

  @spec list_users(keyword) :: %{data: [User.t()], total: integer}
  defdelegate list_users(opts \\ []), to: Users

  @spec create_user(map) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  defdelegate create_user(attrs), to: Users

  @spec get_user(binary) :: User.t() | nil
  defdelegate get_user(id), to: Users

  @spec get_user!(binary) :: User.t()
  defdelegate get_user!(id), to: Users

  @spec get_user_by(keyword) :: User.t() | nil
  defdelegate get_user_by(filter), to: Users

  @spec user_exists?(binary) :: boolean
  defdelegate user_exists?(id), to: Users

  @spec update_user(User.t(), map) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  defdelegate update_user(user, attrs), to: Users

  # def has_role?(user_id, role_name) when is_binary(user_id) and is_binary(role_name) do
  #   user_id
  #   |> get_user!()
  #   |> has_role?(role_name)
  # end

  # def can?(user_id, permission_name) when is_binary(user_id) and is_binary(permission_name) do
  #   user_id
  #   |> get_user!()
  #   |> can?(permission_name)
  # end
end
