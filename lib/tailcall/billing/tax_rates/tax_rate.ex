defmodule Tailcall.Billing.TaxRates.TaxRate do
  use Ecto.Schema

  import Ecto.Changeset, only: [cast: 3, validate_required: 2]

  alias Tailcall.Accounts.Users.User

  @type t :: %__MODULE__{
          active: boolean,
          created_at: DateTime.t(),
          description: binary | nil,
          deleted_at: DateTime.t() | nil,
          display_name: binary,
          id: binary,
          inserted_at: DateTime.t(),
          inclusive: boolean,
          jurisdiction: binary | nil,
          livemode: boolean,
          metadata: map | nil,
          percentage: Decimal.t(),
          object: binary,
          updated_at: DateTime.t(),
          user: User.t(),
          user_id: binary
        }

  @primary_key {:id, Shortcode.Ecto.ID, prefix: "txr", autogenerate: true}
  schema "tax_rates" do
    field(:object, :string, default: "tax_rate")

    belongs_to(:user, User, type: Shortcode.Ecto.ID, prefix: "usr")

    field(:active, :boolean, default: true)
    field(:created_at, :utc_datetime)
    field(:description, :string)
    field(:display_name, :string)
    field(:inclusive, :boolean)
    field(:jurisdiction, :string)
    field(:livemode, :boolean)
    field(:metadata, :map)
    field(:percentage, :decimal)

    field(:deleted_at, :utc_datetime)
    timestamps(type: :utc_datetime)
  end

  @spec create_changeset(TaxRate.t(), map()) :: Ecto.Changeset.t()
  def create_changeset(%__MODULE__{} = tax_rate, attrs) when is_map(attrs) do
    tax_rate
    |> cast(attrs, [
      :user_id,
      :active,
      :created_at,
      :description,
      :display_name,
      :inclusive,
      :jurisdiction,
      :livemode,
      :metadata,
      :percentage
    ])
    |> validate_required([
      :user_id,
      :active,
      :created_at,
      :display_name,
      :inclusive,
      :livemode,
      :percentage
    ])
  end

  @spec update_changeset(TaxRate.t(), map()) :: Ecto.Changeset.t()
  def update_changeset(%__MODULE__{} = tax_rate, attrs) when is_map(attrs) do
    tax_rate
    |> cast(attrs, [:active, :description, :display_name, :jurisdiction, :metadata])
  end

  @spec delete_changeset(TaxRate.t(), map()) :: Ecto.Changeset.t()
  def delete_changeset(%__MODULE__{} = tax_rate, attrs) when is_map(attrs) do
    tax_rate
    |> cast(attrs, [:deleted_at])
    |> validate_required([:deleted_at])
    |> AntlUtilsEcto.Changeset.validate_datetime_gte(:deleted_at, :created_at)
  end
end
