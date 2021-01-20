defmodule Tailcall.Accounts.ApiKeys.ApiKeyUsage do
  use Ecto.Schema

  import Ecto.Changeset,
    only: [
      assoc_constraint: 2,
      cast: 3,
      validate_required: 2
    ]

  alias Tailcall.Accounts.ApiKeys.ApiKey

  @type t :: %__MODULE__{
          ip_address: binary | nil,
          request_id: binary | nil,
          used_at: DateTime.t(),
          id: binary,
          inserted_at: DateTime.t(),
          object: binary,
          updated_at: DateTime.t()
        }

  @primary_key {:id, Shortcode.Ecto.ID, prefix: "aku", autogenerate: true}
  schema "api_key_usages" do
    field(:object, :string, default: "api_key_usage")

    belongs_to(:api_key, ApiKey, type: Shortcode.Ecto.ID, prefix: "ak")

    field(:ip_address, :string)
    field(:request_id, :string)
    field(:used_at, :utc_datetime_usec)

    timestamps(type: :utc_datetime)
  end

  @spec changeset(ApiKeyUsage.t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = api_key_usage, attrs) when is_map(attrs) do
    api_key_usage
    |> cast(attrs, [:api_key_id, :ip_address, :request_id, :used_at])
    |> validate_required([:api_key_id, :used_at])
    |> assoc_constraint(:api_key)
  end
end
