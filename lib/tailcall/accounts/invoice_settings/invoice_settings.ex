defmodule Tailcall.Accounts.InvoiceSettings do
  use Ecto.Schema

  import Ecto.Changeset, only: [cast: 3]

  @type t :: %__MODULE__{}

  @primary_key false
  embedded_schema do
    field(:days_until_due, :integer)
    field(:invoice_prefix, :string)
    field(:next_invoice_sequence_livemode, :integer, default: 1)
    field(:next_invoice_sequence_testmode, :integer, default: 1)
    field(:numbering_scheme, :string, default: "account_level")
  end

  @spec numbering_scheme :: %{account_level: binary, customer_level: binary}
  def numbering_scheme, do: %{account_level: "account_level", customer_level: "customer_level"}

  @spec changeset(InvoiceSettings.t(), map) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = invoice_settings, attrs) when is_map(attrs) do
    invoice_settings
    |> cast(attrs, [
      :days_until_due,
      :invoice_prefix,
      :next_invoice_sequence_livemode,
      :next_invoice_sequence_testmode,
      :numbering_scheme
    ])
  end
end
