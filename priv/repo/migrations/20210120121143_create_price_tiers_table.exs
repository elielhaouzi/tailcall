defmodule Tailcall.Repo.Migrations.CreatePriceTiersTable do
  use Ecto.Migration

  def change do
    create table(:price_tiers) do
      add(:price_id, references(:prices, on_delete: :nothing), null: false)

      add(:flat_amount, :integer, null: true)
      add(:flat_amount_decimal, :decimal, null: true)
      add(:unit_amount, :integer, null: true)
      add(:unit_amount_decimal, :decimal, null: true)
      add(:up_to, :integer, null: true)

      timestamps()
      add(:object, :string, default: "price_tier")
    end
  end
end
