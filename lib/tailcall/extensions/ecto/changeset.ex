defmodule Tailcall.Extensions.Ecto.Changeset do
  import Ecto.Changeset, only: [get_field: 2, put_change: 3]

  def equalize_integer_and_decimal_fields(
        %Ecto.Changeset{} = changeset,
        integer_field,
        decimal_field
      )
      when is_atom(integer_field) and is_atom(decimal_field) do
    integer_value = get_field(changeset, integer_field)
    decimal_value = get_field(changeset, decimal_field)

    case {is_nil(integer_value), is_nil(decimal_value)} do
      {false, true} ->
        changeset |> put_change(decimal_field, Decimal.new(integer_value))

      {true, false} ->
        unless integer?(decimal_value) do
          changeset
        else
          {decimal_to_integer, _} = decimal_value |> Decimal.to_string(:normal) |> Integer.parse()

          changeset |> put_change(integer_field, decimal_to_integer)
        end

      _ ->
        changeset
    end
  end

  defp integer?(%Decimal{} = decimal), do: decimal |> Decimal.rem(1) |> Decimal.eq?(0)
  defp integer?(number) when is_integer(number), do: true
end
