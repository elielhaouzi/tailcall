defmodule Billing.Audit.Events.Event do
  use Ecto.Schema

  import Ecto.Changeset, only: [cast: 3, validate_required: 2]

  alias Billing.Accounts.Users.User

  @primary_key {:id, Shortcode.Ecto.ID, prefix: "evt", autogenerate: true}
  schema "events" do
    field(:object, :string, default: "event")

    belongs_to(:user, User, type: Shortcode.Ecto.ID, prefix: "usr")

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

  @spec changeset(Event.t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = event, attrs) when is_map(attrs) do
    event
    |> cast(attrs, [
      :user_id,
      :api_version,
      :created_at,
      :data,
      :livemode,
      :request_id,
      :resource_id,
      :resource_type,
      :type
    ])
    |> validate_required([:user_id, :created_at, :data, :livemode, :type])
  end
end
