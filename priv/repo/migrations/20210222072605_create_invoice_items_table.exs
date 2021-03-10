defmodule Tailcall.Repo.Migrations.CreateInvoiceItemsTable do
  use Ecto.Migration

  def change do
    create table(:invoice_items) do
      add(:account_id, :bigint, null: false)
      add(:customer_id, :bigint, null: false)
      add(:price_id, references(:prices, on_delete: :nothing), null: true)
      add(:subscription_id, references(:subscriptions, on_delete: :nothing), null: true)

      add(
        :subscription_item_id,
        references(:subscription_items, on_delete: :nothing),
        null: true
      )

      add(:invoice_id, references(:invoices, on_delete: :nothing), null: true)

      add(:amount, :integer, null: false)
      add(:created_at, :utc_datetime, null: true)
      add(:currency, :string, null: false)
      add(:description, :string, null: false)
      add(:is_discountable, :boolean, null: false)
      add(:is_proration, :boolean, null: false)
      add(:livemode, :boolean, null: false)
      add(:metadata, :map, null: false)
      add(:period_end, :utc_datetime, null: false)
      add(:period_start, :utc_datetime, null: false)
      add(:quantity, :integer, null: false)
      add(:unit_amount, :integer, null: true)
      add(:unit_amount_decimal, :decimal, null: true)

      add(:deleted_at, :utc_datetime, null: true)
      timestamps()
      add(:object, :string, default: "invoiceitem")
    end

    create(index(:invoice_items, [:account_id]))
    create(index(:invoice_items, [:customer_id]))
    create(index(:invoice_items, [:period_end]))
    create(index(:invoice_items, [:period_start]))
  end
end
