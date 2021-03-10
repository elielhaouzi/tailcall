defmodule Tailcall.Repo.Migrations.CreatePricesTable do
  use Ecto.Migration

  def change do
    create table(:prices) do
      add(:account_id, :bigint, null: false)
      add(:product_id, references(:products, on_delete: :nothing), null: false)

      add(:active, :boolean, null: false)
      add(:billing_scheme, :string, null: true)
      add(:created_at, :utc_datetime, null: false)
      add(:currency, :string, null: false)
      add(:livemode, :boolean, null: false)
      add(:metadata, :map, null: false)
      add(:nickname, :string, null: true)
      add(:recurring_aggregate_usage, :string, null: true)
      add(:recurring_interval, :string, null: true)
      add(:recurring_interval_count, :integer, null: true)
      add(:recurring_usage_type, :string, null: true)
      add(:tiers_mode, :string, null: true)
      add(:transform_quantity_divide_by, :integer, null: true)
      add(:transform_quantity_round, :string, null: true)
      add(:type, :string, null: false)
      add(:unit_amount, :integer, null: true)
      add(:unit_amount_decimal, :decimal, null: true)

      add(:deleted_at, :utc_datetime, null: true)
      timestamps()
      add(:object, :string, default: "price")
    end

    create(index(:prices, [:account_id]))

    create(index(:prices, [:active]))
    create(index(:prices, [:created_at]))
    create(index(:prices, [:deleted_at]))
    create(index(:prices, [:livemode]))
    create(index(:prices, [:type]))
  end
end
