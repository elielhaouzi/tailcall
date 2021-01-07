defmodule Tailcall.Accounts.Behaviour do
  @callback authenticate(map) ::
              {:ok, %{api_key: map, user: map}} | {:error, :unauthorized | :forbidden}
  @callback livemode?(ApiKey.t()) :: boolean

  @callback list_users(keyword) :: %{data: [User.t()], total: integer}
  @callback create_user(map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  @callback get_user(binary) :: User.t() | nil
  @callback get_user!(binary) :: User.t()
  @callback get_user_by(keyword) :: User.t() | nil
  @callback user_exists?(binary) :: boolean
  @callback update_user(User.t(), map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}

  # @callback has_role?(binary, binary) :: boolean
  # @callback can?(binary, binary) :: boolean
end
