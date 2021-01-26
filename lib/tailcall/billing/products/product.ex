defmodule Tailcall.Billing.Products.Product do
  use Ecto.Schema

  import Ecto.Changeset, only: [cast: 3, validate_inclusion: 3, validate_required: 2]

  alias Tailcall.Accounts.Account

  @type t :: %__MODULE__{
          account: Account.t(),
          account_id: binary,
          active: boolean,
          caption: binary | nil,
          created_at: DateTime.t(),
          description: binary | nil,
          deleted_at: DateTime.t() | nil,
          id: binary,
          inserted_at: DateTime.t(),
          livemode: boolean,
          metadata: map | nil,
          name: binary,
          object: binary,
          statement_descriptor: binary | nil,
          type: binary,
          unit_label: binary | nil,
          url: binary | nil,
          updated_at: DateTime.t()
        }

  @primary_key {:id, Shortcode.Ecto.ID, prefix: "prod", autogenerate: true}
  schema "products" do
    field(:object, :string, default: "product")

    belongs_to(:account, Account, type: Shortcode.Ecto.ID, prefix: "acct")

    field(:active, :boolean, default: true)
    field(:caption, :string)
    field(:created_at, :utc_datetime)
    field(:description, :string)
    field(:livemode, :boolean)
    field(:metadata, :map, default: %{})
    field(:name, :string)
    field(:statement_descriptor, :string)
    field(:type, :string)
    field(:unit_label, :string)
    field(:url, :string)

    field(:deleted_at, :utc_datetime)
    timestamps(type: :utc_datetime)
  end

  @spec product_types :: %{good: binary(), service: binary()}
  def product_types(), do: %{good: "good", service: "service"}

  @spec create_changeset(Product.t(), map()) :: Ecto.Changeset.t()
  def create_changeset(%__MODULE__{} = product, attrs) when is_map(attrs) do
    product
    |> cast(attrs, [
      :account_id,
      :active,
      :caption,
      :created_at,
      :description,
      :livemode,
      :metadata,
      :name,
      :statement_descriptor,
      :type,
      :unit_label,
      :url
    ])
    |> validate_required([:account_id, :active, :created_at, :livemode, :name, :type])
    |> validate_inclusion(:type, Map.values(product_types()))
  end

  @spec update_changeset(Product.t(), map()) :: Ecto.Changeset.t()
  def update_changeset(%__MODULE__{} = product, attrs) when is_map(attrs) do
    product
    |> cast(attrs, [
      :active,
      :caption,
      :description,
      :metadata,
      :name,
      :statement_descriptor,
      :unit_label,
      :url
    ])
    |> validate_required([:active, :name])
  end

  @spec delete_changeset(Product.t(), map()) :: Ecto.Changeset.t()
  def delete_changeset(%__MODULE__{} = product, attrs) when is_map(attrs) do
    product
    |> cast(attrs, [:deleted_at])
    |> validate_required([:deleted_at])
    |> AntlUtilsEcto.Changeset.validate_datetime_gte(:deleted_at, :created_at)
  end
end
