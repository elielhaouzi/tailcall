defmodule Tailcall.Billing.Invoices.StatusTransitions do
  use Ecto.Schema

  import Ecto.Changeset, only: [cast: 3]

  @type t :: %__MODULE__{}

  @primary_key false
  embedded_schema do
    field(:finalized_at, :utc_datetime)
    field(:marked_uncollectible_at, :utc_datetime)
    field(:paid_at, :utc_datetime)
    field(:voided_at, :utc_datetime)
  end

  @spec changeset(InvoiceSettings.t(), map) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = invoice_settings, attrs) when is_map(attrs) do
    invoice_settings
    |> cast(attrs, [:finalized_at, :marked_uncollectible_at, :paid_at, :voided_at])
  end
end
