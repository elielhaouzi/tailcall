defmodule Tailcall.Core.Customers.InvoiceSettings.CustomField do
  use Ecto.Schema

  import Ecto.Changeset, only: [cast: 3, validate_length: 3, validate_required: 2]

  @type t :: %__MODULE__{name: binary, value: binary}

  @primary_key false
  embedded_schema do
    field(:name, :string)
    field(:value, :string)
  end

  @spec changeset(Customer.t(), map) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = custom_field, attrs) when is_map(attrs) do
    custom_field
    |> cast(attrs, [:name, :value])
    |> validate_required([:name, :value])
    |> validate_length(:name, max: 30)
    |> validate_length(:value, max: 30)
  end
end
