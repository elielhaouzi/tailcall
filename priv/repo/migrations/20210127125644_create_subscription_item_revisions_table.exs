defmodule Tailcall.Repo.Migrations.CreateSubscriptionItemRevisionsTable do
  use Ecto.Migration

  def change do
    # create table(:subscription_item_revisions) do
    #   add(
    #     :subscription_item_id,
    #     references(:subscription_items, type: :bigint, on_delete: :delete_all),
    #     null: false
    #   )

    #   # add(:billing_thresholds_amount_gte, :integer, null: true)
    #   add(:bills_cycle_at, :string, null: false)
    #   add(:created_at, :utc_datetime, null: false)
    #   add(:deleted_at, :utc_datetime, null: true)
    #   add(:metadata, :map, null: true)
    #   add(:price_id, references(:prices, on_delete: :nothing), null: false)
    #   add(:quantity, :integer, null: false)

    #   timestamps()
    #   add(:object, :string, default: "subscription_item_revision")
    # end

    # create(index(:subscription_item_revisions, [:bills_cycle_at]))
    # create(index(:subscription_item_revisions, [:created_at]))
    # create(index(:subscription_item_revisions, [:deleted_at]))
  end
end
