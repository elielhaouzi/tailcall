defmodule Billing.Accounts.ApiKeys.ApiKey do
  use Ecto.Schema

  import Ecto.Changeset,
    only: [
      assoc_constraint: 2,
      cast: 3,
      unique_constraint: 2,
      validate_inclusion: 3,
      validate_length: 3,
      validate_required: 2
    ]

  alias Billing.Accounts.Users.User

  @buffer_time_in_seconds 100
  @key_min_length 35
  @key_max_length 245
  @types ["publishable", "secret"]
  @one_day_in_seconds 24 * 3600
  @max_expiration_in_days 7

  @type t :: %__MODULE__{
          created_at: DateTime.t(),
          expired_at: DateTime.t() | nil,
          id: binary,
          inserted_at: DateTime.t(),
          livemode: binary,
          last_used_ip_address: binary | nil,
          last_used_at: DateTime.t() | nil,
          object: binary,
          secret: binary,
          user: User.t(),
          user_id: binary,
          updated_at: DateTime.t()
        }

  @primary_key {:id, Shortcode.Ecto.ID, prefix: "ak", autogenerate: true}
  schema "api_keys" do
    field(:object, :string, default: "api_key")

    belongs_to(:user, User, type: Shortcode.Ecto.ID, prefix: "usr")

    field(:created_at, :utc_datetime)
    field(:expired_at, :utc_datetime)
    field(:livemode, :boolean)
    field(:last_used_ip_address, Billing.Extensions.Ecto.IPAddress, virtual: true)
    field(:last_used_at, :utc_datetime, virtual: true)
    field(:secret, :string)
    field(:type, :string)

    timestamps(type: :utc_datetime)
  end

  @spec create_changeset(ApiKey.t(), map()) :: Ecto.Changeset.t()
  def create_changeset(%__MODULE__{} = api_key, attrs) when is_map(attrs) do
    api_key
    |> cast(attrs, [:user_id, :created_at, :expired_at, :livemode, :secret, :type])
    |> validate_required([:user_id, :created_at, :livemode, :secret, :type])
    |> validate_length(:secret, min: @key_min_length, max: @key_max_length)
    |> validate_inclusion(:type, @types)
    |> unique_constraint(:secret)
    |> assoc_constraint(:user)
  end

  @spec remove_changeset(ApiKey.t(), map()) :: Ecto.Changeset.t()
  def remove_changeset(%__MODULE__{} = api_key, attrs) when is_map(attrs) do
    max_expired_at =
      DateTime.utc_now()
      |> DateTime.add(
        @max_expiration_in_days * @one_day_in_seconds + @buffer_time_in_seconds,
        :second
      )
      |> DateTime.truncate(:second)

    api_key
    |> cast(attrs, [:expired_at])
    |> AntlUtilsEcto.Changeset.validate_datetime_gte(:expired_at, :created_at)
    |> AntlUtilsEcto.Changeset.validate_datetime_lte(:expired_at, max_expired_at)
  end
end
