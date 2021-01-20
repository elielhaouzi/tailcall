defmodule Tailcall.Billing.TaxRates do
  @moduledoc """
  The TaxRates context.
  """
  alias Tailcall.Repo
  alias Tailcall.Accounts

  alias Tailcall.Billing.TaxRates.TaxRate

  @spec create_tax_rate(map()) :: {:ok, TaxRate.t()} | {:error, Ecto.Changeset.t()}
  def create_tax_rate(attrs) when is_map(attrs) do
    %TaxRate{}
    |> TaxRate.create_changeset(attrs)
    |> validate_create_changes()
    |> Repo.insert()
  end

  @spec get_tax_rate(binary) :: TaxRate.t() | nil
  def get_tax_rate(id) when is_binary(id) do
    TaxRate
    |> Repo.get(id)
  end

  @spec update_tax_rate(TaxRate.t(), map()) ::
          {:ok, TaxRate.t()} | {:error, Ecto.Changeset.t()}
  def update_tax_rate(%TaxRate{deleted_at: nil} = tax_rate, attrs) when is_map(attrs) do
    tax_rate
    |> TaxRate.update_changeset(attrs)
    |> Repo.update()
  end

  @spec delete_tax_rate(TaxRate.t(), map()) ::
          {:ok, TaxRate.t()} | {:error, Ecto.Changeset.t()}
  def delete_tax_rate(%TaxRate{deleted_at: nil} = tax_rate, %DateTime{} = delete_at) do
    tax_rate
    |> TaxRate.delete_changeset(%{deleted_at: delete_at})
    |> Repo.update()
  end

  defp validate_create_changes(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp validate_create_changes(changeset) do
    Ecto.Changeset.prepare_changes(changeset, fn changeset ->
      changeset
      |> assoc_constraint_user()
    end)
  end

  defp assoc_constraint_user(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp assoc_constraint_user(%Ecto.Changeset{valid?: true} = changeset) do
    user_id = Ecto.Changeset.get_field(changeset, :user_id)

    if Accounts.user_exists?(user_id) do
      changeset
    else
      changeset |> Ecto.Changeset.add_error(:user, "does not exist")
    end
  end
end
