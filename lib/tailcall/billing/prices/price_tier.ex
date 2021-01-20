defmodule Tailcall.Billing.Prices.PriceTier do
  use Ecto.Schema

  import Ecto.Changeset, only: [assoc_constraint: 2, cast: 3, get_field: 2, validate_number: 3]

  alias Tailcall.Extensions.Ecto.Changeset, as: TailcallExtensionsEctoChangeset

  alias Tailcall.Billing.Prices.Price

  schema "price_tiers" do
    belongs_to(:price, Price, type: Shortcode.Ecto.ID, prefix: "price")

    field(:flat_amount, :integer)
    field(:flat_amount_decimal, :decimal)
    field(:unit_amount, :integer)
    field(:unit_amount_decimal, :decimal)
    field(:up_to, :integer)

    timestamps(type: :utc_datetime)
  end

  @spec changeset(PriceTier.t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = price_tier, attrs) when is_map(attrs) do
    price_tier
    |> cast(attrs, [
      :up_to,
      :unit_amount,
      :unit_amount_decimal,
      :flat_amount,
      :flat_amount_decimal
    ])
    |> validate_number(:flat_amount, greater_than_or_equal_to: 0)
    |> validate_number(:flat_amount_decimal, greater_than_or_equal_to: 0)
    |> validate_number(:unit_amount, greater_than_or_equal_to: 0)
    |> validate_number(:unit_amount_decimal, greater_than_or_equal_to: 0)
    |> validate_number(:up_to, greater_than: 0)
    |> AntlUtilsEcto.Changeset.validate_required_any(
      [
        :unit_amount,
        :unit_amount_decimal,
        :flat_amount,
        :flat_amount_decimal
      ],
      key: :tier
    )
    |> validate_flat_amount()
    |> TailcallExtensionsEctoChangeset.equalize_integer_and_decimal_fields(
      :flat_amount,
      :flat_amount_decimal
    )
    |> validate_unit_amount()
    |> TailcallExtensionsEctoChangeset.equalize_integer_and_decimal_fields(
      :unit_amount,
      :unit_amount_decimal
    )
    |> assoc_constraint(:price)
  end

  defp validate_flat_amount(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp validate_flat_amount(changeset) do
    flat_amount = get_field(changeset, :flat_amount)
    flat_amount_decimal = get_field(changeset, :flat_amount_decimal)

    if is_nil(flat_amount) and is_nil(flat_amount_decimal) do
      changeset
    else
      changeset
      |> AntlUtilsEcto.Changeset.validate_required_one_exclusive(
        [:flat_amount, :flat_amount_decimal],
        key: :tier
      )
    end
  end

  defp validate_unit_amount(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp validate_unit_amount(changeset) do
    unit_amount = get_field(changeset, :unit_amount)
    unit_amount_decimal = get_field(changeset, :unit_amount_decimal)

    if is_nil(unit_amount) and is_nil(unit_amount_decimal) do
      changeset
    else
      changeset
      |> AntlUtilsEcto.Changeset.validate_required_one_exclusive(
        [:unit_amount, :unit_amount_decimal],
        key: :tier
      )
    end
  end
end
