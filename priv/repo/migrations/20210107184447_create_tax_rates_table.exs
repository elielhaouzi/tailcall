defmodule Tailcall.Repo.Migrations.CreateTaxRatesTable do
  use Ecto.Migration

  def change do
    create table(:tax_rates) do
      add(:account_id, :bigint, null: false)

      add(:active, :boolean, null: false)
      add(:created_at, :utc_datetime, null: false)
      add(:description, :string, null: true)
      add(:display_name, :string, null: false)
      add(:inclusive, :boolean, null: false)
      add(:jurisdiction, :string, null: true)
      add(:livemode, :boolean, null: false)
      add(:metadata, :map, null: true)
      add(:percentage, :decimal, null: false)

      add(:deleted_at, :utc_datetime, null: true)
      timestamps()
      add(:object, :string, default: "tax_rate")
    end

    create(index(:tax_rates, [:user_id]))
    create(index(:tax_rates, [:active]))
    create(index(:tax_rates, [:created_at]))
    create(index(:tax_rates, [:deleted_at]))
    create(index(:tax_rates, [:livemode]))
  end
end
