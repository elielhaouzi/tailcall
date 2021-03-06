defmodule Tailcall.Core.Customers.InvoiceSettings do
  use Ecto.Schema

  import Ecto.Changeset, only: [cast: 3, cast_embed: 3]

  alias Tailcall.Core.Customers.InvoiceSettings.CustomField

  @type t :: %__MODULE__{
          custom_fields: [CustomField.t()],
          footer: binary | nil
        }

  @primary_key false
  embedded_schema do
    embeds_many(:custom_fields, CustomField)
    field(:footer, :string)
  end

  @spec changeset(Customer.t(), map) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = customer, attrs) when is_map(attrs) do
    customer
    |> cast(attrs, [:footer])
    |> cast_embed(:custom_fields, required: false)
  end
end
