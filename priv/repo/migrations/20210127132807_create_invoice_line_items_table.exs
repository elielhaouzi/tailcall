defmodule Tailcall.Repo.Migrations.CreateInvoiceLineItemsTable do
  use Ecto.Migration

  def change do
    create table(:invoice_line_items) do
      add(:invoice_id, references(:invoices, type: :bigint, on_delete: :nothing), null: false)

      add(:price_id, references(:prices, type: :bigint, on_delete: :nothing), null: false)

      add(:subscription_id, references(:subscriptions, type: :bigint, on_delete: :nothing),
        null: true
      )

      add(
        :subscription_item_id,
        references(:subscription_items, type: :bigint, on_delete: :nothing),
        null: true
      )

      add(:amount, :integer, null: false)
      add(:created_at, :utc_datetime, null: false)
      add(:currency, :string, null: false)
      add(:livemode, :boolean, null: false)
      add(:period_end, :utc_datetime, null: false)
      add(:period_start, :utc_datetime, null: false)
      add(:quantity, :integer, null: true)
      add(:type, :string, null: false)

      timestamps()
      add(:object, :string, default: "invoice_line_item")
    end

    create(index(:invoice_line_items, [:created_at]))
    create(index(:invoice_line_items, [:livemode]))
    create(index(:invoice_line_items, [:period_end]))
    create(index(:invoice_line_items, [:period_start]))
  end
end
