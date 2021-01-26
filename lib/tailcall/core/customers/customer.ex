defmodule Tailcall.Core.Customers.Customer do
  use Ecto.Schema

  import Ecto.Changeset,
    only: [cast: 3, put_embed: 3, validate_inclusion: 3, validate_number: 3, validate_required: 2]

  alias Tailcall.Accounts.Account
  alias Tailcall.Core.Customers.InvoiceSettings

  @type t :: %__MODULE__{
          account: Account.t(),
          account_id: binary,
          balance: integer,
          currency: binary | nil,
          created_at: DateTime.t(),
          delinquent: boolean,
          description: binary | nil,
          deleted_at: DateTime.t() | nil,
          email: binary | nil,
          id: binary,
          inserted_at: DateTime.t(),
          invoice_prefix: binary,
          invoice_settings: InvoiceSettings.t(),
          livemode: boolean,
          metadata: map | nil,
          name: binary,
          next_invoice_sequence: integer,
          object: binary,
          phone: binary,
          preferred_locales: [binary],
          tax_exempt: binary,
          updated_at: DateTime.t()
        }

  @primary_key {:id, Shortcode.Ecto.ID, prefix: "cus", autogenerate: true}
  schema "customers" do
    field(:object, :string, default: "customers")

    belongs_to(:account, Account, type: Shortcode.Ecto.ID, prefix: "acct")

    field(:balance, :integer, default: 0)
    field(:currency, :string)
    field(:created_at, :utc_datetime)
    field(:delinquent, :boolean, default: false)
    field(:description, :string)
    field(:email, :string)
    field(:invoice_prefix, :string)
    embeds_one(:invoice_settings, InvoiceSettings)
    field(:livemode, :boolean)
    field(:metadata, :map, default: %{})
    field(:name, :string)
    field(:next_invoice_sequence, :integer, default: 1)
    field(:phone, :string)
    field(:preferred_locales, {:array, :string}, default: [])
    field(:tax_exempt, :string, default: "none")

    field(:deleted_at, :utc_datetime)
    timestamps(type: :utc_datetime)
  end

  @spec tax_exempts :: %{none: binary, exempt: binary, reverse: binary}
  def tax_exempts, do: %{none: "none", exempt: "exempt", reverse: "reverse"}

  @spec create_changeset(Customer.t(), map) :: Ecto.Changeset.t()
  def create_changeset(%__MODULE__{} = customer, attrs) when is_map(attrs) do
    customer
    |> cast(attrs, [
      :account_id,
      :balance,
      :currency,
      :created_at,
      :description,
      :email,
      :invoice_prefix,
      :livemode,
      :metadata,
      :name,
      :next_invoice_sequence,
      :phone,
      :preferred_locales,
      :tax_exempt
    ])
    |> put_embed(:invoice_settings, %{})
    |> validate_required([:account_id, :created_at, :balance, :livemode, :next_invoice_sequence])
    |> validate_number(:next_invoice_sequence, greater_than_or_equal_to: 1)
    |> validate_inclusion(:tax_exempt, Map.values(tax_exempts()))
  end

  @spec update_changeset(Customer.t(), map) :: Ecto.Changeset.t()
  def update_changeset(%__MODULE__{} = customer, attrs) when is_map(attrs) do
    customer
    |> cast(attrs, [
      :balance,
      :delinquent,
      :description,
      :email,
      :metadata,
      :invoice_prefix,
      :name,
      :next_invoice_sequence,
      :phone,
      :preferred_locales,
      :tax_exempt
    ])
    # |> put_embed(:invoice_settings, %{})
    |> validate_required([:balance, :next_invoice_sequence])
    |> validate_number(:next_invoice_sequence, greater_than_or_equal_to: 1)
  end

  @spec delete_changeset(Customer.t(), map) :: Ecto.Changeset.t()
  def delete_changeset(%__MODULE__{} = customer, attrs) when is_map(attrs) do
    customer
    |> cast(attrs, [:deleted_at])
    |> validate_required([:deleted_at])
    |> AntlUtilsEcto.Changeset.validate_datetime_gte(:deleted_at, :created_at)
  end
end
