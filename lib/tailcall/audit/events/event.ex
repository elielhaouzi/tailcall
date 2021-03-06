defmodule Tailcall.Audit.Events.Event do
  use Ecto.Schema

  import Ecto.Changeset, only: [cast: 3, validate_required: 2]

  alias Tailcall.Accounts.Account

  @type t :: %__MODULE__{
          account: Account.t(),
          account_id: binary,
          api_version: binary,
          created_at: DateTime.t(),
          data: map,
          livemode: boolean,
          request_id: binary | nil,
          resource_id: binary | nil,
          resource_type: binary | nil,
          type: binary,
          id: binary,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @primary_key {:id, Shortcode.Ecto.ID, prefix: "evt", autogenerate: true}
  schema "events" do
    field(:object, :string, default: "event")

    belongs_to(:account, Account, type: Shortcode.Ecto.ID, prefix: "acct")

    field(:api_version, :string, default: "2021-01-01")
    field(:created_at, :utc_datetime)
    field(:data, :map)
    field(:livemode, :boolean)
    field(:request_id, :string)
    field(:resource_id, :string)
    field(:resource_type, :string)
    field(:type, :string)

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = event, attrs) when is_map(attrs) do
    event
    |> cast(attrs, [
      :account_id,
      :api_version,
      :created_at,
      :data,
      :livemode,
      :request_id,
      :resource_id,
      :resource_type,
      :type
    ])
    |> validate_required([:account_id, :created_at, :data, :livemode, :type])
  end
end
