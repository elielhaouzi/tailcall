defmodule Tailcall.Repo.Migrations.CreateSubscriptionItemsTable do
  use Ecto.Migration

  def change do
    create table(:subscription_items) do
      add(:subscription_id, references(:subscriptions, on_delete: :nothing), null: false)

      # add(:billing_thresholds_amount_gte, :integer, null: true)
      # add(:bills_cycle_at, :string, null: false)
      add(:created_at, :utc_datetime, null: false)
      add(:metadata, :map, null: false)
      add(:price_id, references(:prices, on_delete: :nothing), null: false)
      add(:quantity, :integer, null: true)

      add(:deleted_at, :utc_datetime, null: true)
      timestamps()
      add(:object, :string, default: "subscription_item")
    end

    # create(index(:subscription_items, [:bills_cycle_at]))
    create(index(:subscription_items, [:created_at]))
    create(index(:subscription_items, [:deleted_at]))
  end
end
