defmodule Tailcall.Accounts.Account do
  use Ecto.Schema

  import Ecto.Changeset, only: [cast: 3, put_embed: 3, validate_required: 2]

  alias Tailcall.Accounts.InvoiceSettings

  @type t :: %__MODULE__{
          api_version: binary,
          created_at: DateTime.t(),
          deleted_at: DateTime.t() | nil,
          id: binary,
          inserted_at: DateTime.t(),
          name: binary | nil,
          object: binary,
          updated_at: DateTime.t()
        }

  @primary_key {:id, Shortcode.Ecto.ID, prefix: "acct", autogenerate: true}
  schema "accounts" do
    field(:object, :string, default: "account")

    field(:api_version, :string, default: "2021-01-01")
    field(:created_at, :utc_datetime)
    embeds_one(:invoice_settings, InvoiceSettings)
    field(:name, :string)

    field(:deleted_at, :utc_datetime)
    timestamps(type: :utc_datetime)
  end

  @spec create_changeset(Account.t(), map) :: Ecto.Changeset.t()
  def create_changeset(%__MODULE__{} = account, attrs) when is_map(attrs) do
    account
    |> cast(attrs, [:api_version, :created_at, :name])
    |> put_embed(:invoice_settings, %{})
    |> validate_required([:api_version, :created_at])
  end

  @spec update_changeset(Account.t(), map) :: Ecto.Changeset.t()
  def update_changeset(%__MODULE__{} = account, attrs) when is_map(attrs) do
    account
    |> cast(attrs, [:api_version, :name])
    |> validate_required([:api_version])
  end

  @spec delete_changeset(Account.t(), map) :: Ecto.Changeset.t()
  def delete_changeset(%__MODULE__{} = account, attrs) when is_map(attrs) do
    account
    |> cast(attrs, [:deleted_at])
    |> validate_required([:deleted_at])
    |> AntlUtilsEcto.Changeset.validate_datetime_gte(:deleted_at, :created_at)
  end
end
